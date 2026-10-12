module QaProbe
  # Records every Sidekiq job the same way as a request, so background
  # failures, N+1s and memory use show up even though no browser sees them.
  class SidekiqMiddleware
    def call(_worker, job, _queue)
      recorder = nil
      Recorder.record(kind: 'job', name: job['wrapped'] || job['class']) do |current|
        recorder = current
        yield
        current.status = 'succeeded'
      end
    rescue StandardError
      recorder&.status = 'failed'
      raise
    ensure
      save(recorder) if recorder
    end

    private

    def save(recorder)
      Store.save_job(recorder.report)
    rescue StandardError => e
      Sidekiq.logger.warn("[QaProbe] could not store job report: #{e.class}: #{e.message}")
    end
  end
end
