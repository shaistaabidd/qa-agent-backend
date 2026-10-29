module QaProbe
  # Collects everything one request or job does. Lives in a thread-local while
  # the unit of work runs, so the global SQL subscriber and the :raise
  # TracePoint can attribute events to it.
  class Recorder
    SKIPPED_SQL_NAMES = %w[SCHEMA TRANSACTION].freeze
    # Allocation counts and RSS are process-wide in Ruby, so they're only
    # attributable to one request if no other request/job ran at the same
    # time. Track that, so the report can say whether its memory is its own.
    ACTIVE = Concurrent::AtomicFixnum.new(0)
    STARTED = Concurrent::AtomicFixnum.new(0)
    MAX_EXCEPTIONS = 20
    MAX_BACKTRACE = 15

    attr_accessor :name
    attr_reader :id, :kind

    def self.current
      Thread.current[:qa_probe_recorder]
    end

    def self.record(kind:, name:)
      recorder = new(kind: kind, name: name)
      Thread.current[:qa_probe_recorder] = recorder
      recorder.start
      yield recorder
    rescue Exception => e # rubocop:disable Lint/RescueException -- re-raised; only marks it unhandled
      recorder&.unhandled!(e)
      raise
    ensure
      recorder&.finish
      Thread.current[:qa_probe_recorder] = nil
    end

    def self.subscribe_to_sql!
      return if @sql_subscribed

      @sql_subscribed = true
      ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        current&.record_sql(event)
      end
    end

    def initialize(kind:, name:)
      @id = SecureRandom.hex(12)
      @kind = kind
      @name = name
      @queries = {}
      @query_count = 0
      @cached_count = 0
      @sql_ms = 0.0
      @slow_queries = []
      @exceptions = []
      @seen_exceptions = {}.compare_by_identity
      @unhandled = nil
      @status = nil
    end

    attr_writer :status

    def start
      @active_at_start = ACTIVE.increment - 1
      @start_sequence = STARTED.increment
      @started_at = Time.now.utc
      @clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @allocated_before = GC.stat(:total_allocated_objects)
      @gc_before = GC.count
      @rss_before = self.class.rss_kb
      thread = Thread.current
      @trace = TracePoint.new(:raise) do |tp|
        record_exception(tp.raised_exception) if Thread.current == thread
      end
      @trace.enable
    end

    def finish
      @overlapped = @active_at_start.positive? || STARTED.value != @start_sequence
      ACTIVE.decrement
      @trace&.disable
      @duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @clock) * 1000).round(1)
      @allocated = GC.stat(:total_allocated_objects) - @allocated_before
      @gc_runs = GC.count - @gc_before
      @rss_after = self.class.rss_kb
    end

    def unhandled!(exception)
      record_exception(exception, force: true)
      @unhandled = exception
    end

    # Rails' exception pages rescue a crash to render the 500, so nothing
    # escapes the middleware — but the request still failed. The last app
    # exception before a 5xx is the one that crashed it.
    def response_status!(status)
      @status = status
      @unhandled ||= @last_exception if status.to_i >= 500
    end

    def record_sql(event)
      payload = event.payload
      return if SKIPPED_SQL_NAMES.include?(payload[:name])
      return if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      if payload[:cached]
        @cached_count += 1
        return
      end

      duration = event.duration
      caller_line = self.class.app_frame(caller_locations) || self.class.graphql_field
      shape = Sql.normalize(payload[:sql])
      @query_count += 1
      @sql_ms += duration

      entry = (@queries[[shape,
                         caller_line]] ||= { sql: shape, caller: caller_line, count: 0, total_ms: 0.0, max_ms: 0.0,
                                             sample: payload[:sql].to_s.gsub(%r{/\*.*?\*/}m, "").strip[0, 500] })
      entry[:count] += 1
      entry[:total_ms] += duration
      entry[:max_ms] = [entry[:max_ms], duration].max

      return unless duration >= QaProbe.slow_query_ms && @slow_queries.size < 20

      @slow_queries << { sql: shape, ms: duration.round(1), caller: caller_line }
    end

    def report
      queries = @queries.values
      {
        id: id,
        kind: kind,
        name: name,
        status: @status,
        started_at: @started_at&.iso8601(3),
        duration_ms: @duration_ms,
        # true = other requests/jobs ran concurrently, so memory and timings
        # below include their work too (SQL, N+1 and exceptions are per-thread
        # and always exact).
        overlapped: @overlapped,
        db: { queries: @query_count, cached: @cached_count, total_ms: @sql_ms.round(1) },
        n_plus_one: n_plus_one(queries),
        slow_queries: @slow_queries,
        top_queries: queries.sort_by { |q| -q[:total_ms] }.first(10).map { |q| rounded(q) },
        exceptions: exceptions_with_handling,
        memory: {
          allocated_objects: @allocated,
          gc_runs: @gc_runs,
          rss_before_mb: mb(@rss_before),
          rss_after_mb: mb(@rss_after),
          rss_delta_mb: @rss_before && @rss_after ? mb(@rss_after - @rss_before) : nil
        }
      }
    end

    # The first frame in this app's own code — anything under the app root
    # except vendored gems and the probe itself.
    def self.app_frame(locations)
      location = locations.find { |loc| app_path?(loc) }
      location && "#{(location.absolute_path || location.path).delete_prefix("#{Rails.root}/")}:#{location.lineno}"
    end

    # When a query is triggered by GraphQL resolving a field (e.g. an
    # association loaded per object), no app frame is on the stack — the
    # field ("Run.auditLogEntries") is the useful location instead.
    def self.graphql_field
      return nil unless defined?(GraphQL::Current)

      path = GraphQL::Current.field&.path
      path && "GraphQL field #{path}"
    rescue StandardError
      nil
    end

    def self.app_path?(location)
      path = location.absolute_path || location.path
      root = "#{Rails.root}/"
      path&.start_with?(root) && !path.start_with?("#{root}lib/qa_probe", "#{root}vendor/")
    end

    def self.rss_kb
      File.foreach("/proc/self/status") { |line| return line.split[1].to_i if line.start_with?("VmRSS:") }
      nil
    rescue SystemCallError
      nil
    end

    private

    # The same query shape run repeatedly from the same line of code is the
    # classic N+1: one query per record instead of one for all of them.
    def n_plus_one(queries)
      queries.select { |q| q[:count] >= QaProbe.n_plus_one_threshold && q[:sql].match?(/\A\s*SELECT/i) }
             .sort_by { |q| -q[:count] }
             .map do |q|
               table = Sql.table(q[:sql])
               rounded(q).merge(
                 table: table,
                 suggestion: "Preload the records instead of loading them one at a time" \
                             "#{" (e.g. `includes`/`preload` the association that loads `#{table}`)" if table}."
               )
             end
    end

    # Only exceptions *raised in the app's own code* are recorded: libraries
    # raise and rescue internally all the time (constant lookup, optional
    # requires, caches) and that's not the app's concern. `force` records the
    # one that escapes the request, wherever it was raised.
    def record_exception(exception, force: false)
      return if @seen_exceptions.key?(exception) || @exceptions.size >= MAX_EXCEPTIONS
      return if QaProbe.ignored_exceptions.include?(exception.class.name)

      locations = exception.backtrace_locations || caller_locations
      raise_point = locations.find { |loc| !loc.path.to_s.start_with?("<internal:") }
      return unless force || (raise_point && self.class.app_path?(raise_point))

      location = self.class.app_frame(locations)

      @seen_exceptions[exception] = true
      @last_exception = exception

      @exceptions << {
        class: exception.class.name,
        message: exception.message.to_s[0, 1000],
        location: location,
        backtrace: clean_backtrace(locations),
        handled: true
      }
    end

    def clean_backtrace(locations)
      root = "#{Rails.root}/"
      locations.reject { |loc| loc.path.to_s.start_with?("#{root}lib/qa_probe") }
               .first(MAX_BACKTRACE * 2)
               .map do |loc|
        "#{loc.path.to_s.delete_prefix(root).sub(%r{.*/gems/},
                                                 "gems/")}:#{loc.lineno} in `#{loc.label}`"
      end
               .first(MAX_BACKTRACE)
    end

    def rounded(query)
      query.merge(total_ms: query[:total_ms].round(1), max_ms: query[:max_ms].round(1))
    end

    def mb(kilobytes)
      kilobytes && (kilobytes / 1024.0).round(1)
    end

    # The exception that escaped the request/job is the unhandled one; every
    # other one recorded was rescued somewhere in the app.
    def exceptions_with_handling
      @exceptions.map do |exception|
        unhandled = @unhandled && exception[:class] == @unhandled.class.name &&
                    exception[:message] == @unhandled.message.to_s[0, 1000]
        exception.merge(handled: !unhandled)
      end
    end
  end
end
