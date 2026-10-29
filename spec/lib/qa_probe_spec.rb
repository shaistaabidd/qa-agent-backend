require "rails_helper"
require Rails.root.join("lib/qa_probe").to_s

RSpec.describe QaProbe do
  before { QaProbe::Recorder.subscribe_to_sql! }

  describe QaProbe::Sql do
    it "collapses literals, binds and IN lists into one query shape" do
      sql = %(SELECT "users".* FROM "users" WHERE "users"."id" = $1 AND name = 'x' AND id IN (1, 2, 3) /*app*/)
      shape = described_class.normalize(sql)

      expect(shape).to eq('SELECT "users".* FROM "users" WHERE "users"."id" = ? AND name = ? AND id IN (?)')
      expect(described_class.table(shape)).to eq("users")
    end
  end

  describe QaProbe::Recorder do
    def record(&block)
      recorder = nil
      described_class.record(kind: "request", name: "test") do |current|
        recorder = current
        block.call
      end
      recorder.report
    end

    it "counts queries and flags the same query run per record as an N+1" do
      projects = create_list(:project, 4)

      report = record { projects.each { |project| Project.find(project.id) } }

      expect(report[:db][:queries]).to be >= 4
      n_plus_one = report[:n_plus_one].first
      expect(n_plus_one[:count]).to eq(4)
      expect(n_plus_one[:table]).to eq("projects")
      expect(n_plus_one[:caller]).to start_with("spec/lib/qa_probe_spec.rb:")
    end

    it "does not flag a single batched query" do
      create_list(:project, 4)

      report = record { Project.where(id: Project.select(:id)).to_a }

      expect(report[:n_plus_one]).to be_empty
    end

    it "captures exceptions the app rescues, with location and backtrace" do
      report = record do
        Integer("not a number")
      rescue ArgumentError
        nil
      end

      exception = report[:exceptions].first
      expect(exception).to include(class: "ArgumentError", handled: true)
      expect(exception[:location]).to start_with("spec/lib/qa_probe_spec.rb:")
      expect(exception[:backtrace]).not_to be_empty
    end

    it "marks the exception that escapes as unhandled" do
      expect { record { raise NoMethodError, "boom" } }.to raise_error(NoMethodError)
    end

    it "ignores exceptions raised and rescued inside libraries (e.g. Rails' constant lookup)" do
      report = record { "NoSuchConstantHere".safe_constantize }

      expect(report[:exceptions]).to be_empty
    end

    it "ignores control-flow exceptions like GraphQL::ExecutionError" do
      report = record do
        raise GraphQL::ExecutionError, "Access Denied!"
      rescue GraphQL::ExecutionError
        nil
      end

      expect(report[:exceptions]).to be_empty
    end

    it "flags a report whose memory overlapped another request" do
      inner = nil
      outer = record do
        thread = Thread.new { inner = record { nil } }
        thread.join
      end

      expect(outer[:overlapped]).to be true
      expect(inner[:overlapped]).to be true
      expect(record { nil }[:overlapped]).to be false
    end

    it "reports memory allocated" do
      report = record { Array.new(10_000) { |i| "string #{i}" } }

      expect(report[:memory][:allocated_objects]).to be >= 10_000
    end
  end

  describe QaProbe::Middleware do
    let(:app) { ->(_env) { [200, {}, ["ok"]] } }
    let(:middleware) { described_class.new(app) }

    before do
      allow(QaProbe).to receive(:token).and_return("probe-token")
      allow(QaProbe::Store).to receive(:save_request)
    end

    it "tags the response with the report id and stores the report" do
      status, headers, = middleware.call(Rack::MockRequest.env_for("/graphql", method: "POST"))

      expect(status).to eq(200)
      expect(headers["X-QA-Probe-Id"]).to match(/\A\h{24}\z/)
      expect(QaProbe::Store).to have_received(:save_request).with(hash_including(id: headers["X-QA-Probe-Id"],
                                                                                 status: 200))
    end

    it "records an unhandled exception and still re-raises it" do
      failing = described_class.new(->(_env) { raise "kaboom" })

      expect { failing.call(Rack::MockRequest.env_for("/graphql", method: "POST")) }.to raise_error("kaboom")
      expect(QaProbe::Store).to have_received(:save_request) do |report|
        expect(report[:exceptions].first).to include(class: "RuntimeError", handled: false)
      end
    end

    it "treats the exception behind a 500 response as unhandled" do
      crashing = described_class.new(lambda do |_env|
        raise NotImplementedError, "boom"
      rescue NotImplementedError
        [500, {}, ["error page"]]
      end)

      crashing.call(Rack::MockRequest.env_for("/graphql", method: "POST"))

      expect(QaProbe::Store).to have_received(:save_request) do |report|
        expect(report[:exceptions].first).to include(class: "NotImplementedError", handled: false)
      end
    end

    it "refuses to serve reports without the token" do
      status, = middleware.call(Rack::MockRequest.env_for("/__qa_probe/requests/abc123"))

      expect(status).to eq(401)
    end

    it "serves a stored report with the token" do
      allow(QaProbe::Store).to receive(:request).with("abc123").and_return("id" => "abc123")

      status, _, body = middleware.call(
        Rack::MockRequest.env_for("/__qa_probe/requests/abc123", "HTTP_X_QA_PROBE_TOKEN" => "probe-token")
      )

      expect(status).to eq(200)
      expect(JSON.parse(body.first)).to eq("id" => "abc123")
    end
  end
end
