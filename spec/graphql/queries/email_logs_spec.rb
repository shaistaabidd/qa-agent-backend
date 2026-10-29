require "rails_helper"

RSpec.describe "Email log queries", type: :graphql do
  let(:admin) { create(:user, :super_admin) }
  let(:user) { create(:user) }

  describe "allEmailLogs" do
    let(:query) do
      <<~GQL
        query($filter: EmailLogFilterInput) {
          allEmailLogs(filter: $filter) {
            count currentPage totalPages nextPage prevPage
            allData { recipient status }
          }
        }
      GQL
    end

    def recipients(filter = {})
      execute_graphql(query, variables: { filter: }, as: admin)
        .dig("data", "allEmailLogs", "allData").pluck("recipient")
    end

    it "returns the newest logs first with the frontend's fields" do
      log = create(:email_log, :failed, recipient: "old@example.com", created_at: 1.day.ago)
      create(:email_log, recipient: "new@example.com")
      fields = "id recipient mailer mailerMethod subject body status errorMessage attempts " \
               "sentAt createdAt updatedAt"

      logs = execute_graphql("{ allEmailLogs { allData { #{fields} } } }", as: admin).dig("data", "allEmailLogs",
                                                                                          "allData")

      expect(logs.pluck("recipient")).to eq(%w[new@example.com old@example.com])
      expect(logs[1]).to include(
        "id" => log.id.to_s, "status" => "FAILED", "sentAt" => nil, "attempts" => 1,
        "errorMessage" => "Net::SMTPServerBusy: 451 Try again later"
      )
    end

    it "filters by status" do
      create(:email_log, recipient: "sent@example.com")
      create(:email_log, :failed, recipient: "failed@example.com")

      expect(recipients(status: "FAILED")).to eq(["failed@example.com"])
      expect(recipients(status: "SUCCESS")).to eq(["sent@example.com"])
    end

    it "filters by whole days, inclusive" do
      create(:email_log, recipient: "before@example.com", created_at: Time.zone.local(2026, 10, 1, 23, 59))
      create(:email_log, recipient: "first@example.com", created_at: Time.zone.local(2026, 10, 2, 0, 0))
      create(:email_log, recipient: "last@example.com", created_at: Time.zone.local(2026, 10, 3, 23, 59))
      create(:email_log, recipient: "after@example.com", created_at: Time.zone.local(2026, 10, 4, 0, 0))

      expect(recipients(startDate: "2026-10-02", endDate: "2026-10-03"))
        .to eq(%w[last@example.com first@example.com])
      expect(recipients(startDate: "2026-10-04")).to eq(["after@example.com"])
      expect(recipients(endDate: "2026-10-01")).to eq(["before@example.com"])
    end

    it "searches recipient and subject, treating % and _ literally" do
      create(:email_log, recipient: "jane@example.com", subject: "Your login code")
      create(:email_log, recipient: "john@example.com", subject: "Welcome")

      expect(recipients(search: "jane")).to eq(["jane@example.com"])
      expect(recipients(search: "login code")).to eq(["jane@example.com"])
      expect(recipients(search: "%")).to be_empty
    end

    it "reads bodies only when the client selects them" do
      create(:email_log, body: "<p>Hello</p>")
      logs = ->(fields) { execute_graphql("{ allEmailLogs { allData { #{fields} } } }", as: admin) }
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "email_logs"') }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { logs.call("id") }
      row_query = queries.find { it.include?('"email_logs"."recipient"') }
      expect(row_query).to be_present
      expect(row_query).not_to include('"body"')
      expect(logs.call("body").dig("data", "allEmailLogs", "allData", 0, "body")).to eq("<p>Hello</p>")
    end

    it "paginates" do
      create_list(:email_log, 3)

      result = execute_graphql(query, variables: { filter: { perPage: 2, page: 2 } }, as: admin)
      page = result.dig("data", "allEmailLogs")

      expect(page).to include("count" => 3, "currentPage" => 2, "totalPages" => 2, "nextPage" => nil, "prevPage" => 1)
      expect(page["allData"].size).to eq(1)
    end

    it "rejects an invalid date" do
      result = execute_graphql(query, variables: { filter: { startDate: "not-a-date" } }, as: admin)

      expect(result["errors"]).to be_present
      expect(result["data"]).to be_nil
    end

    it "is only for super admins" do
      expect(error_codes(execute_graphql(query, as: user))).to eq(["FORBIDDEN"])
    end

    it "requires a signed-in caller" do
      expect(error_codes(execute_graphql(query))).to eq(["UNAUTHENTICATED"])
    end
  end

  describe "fetchEmailLog" do
    let(:query) do
      <<~GQL
        query($id: ID!) { fetchEmailLog(id: $id) { id subject body } }
      GQL
    end
    let(:email_log) { create(:email_log, subject: "Your login code") }

    it "returns a log with its body" do
      result = execute_graphql(query, variables: { id: email_log.id }, as: admin)

      expect(result.dig("data", "fetchEmailLog")).to eq(
        "id" => email_log.id.to_s, "subject" => "Your login code", "body" => email_log.body
      )
    end

    it "is only for super admins" do
      expect(error_codes(execute_graphql(query, variables: { id: email_log.id }, as: user))).to eq(["FORBIDDEN"])
    end

    it "returns NOT_FOUND for an unknown id" do
      expect(error_codes(execute_graphql(query, variables: { id: 0 }, as: admin))).to eq(["NOT_FOUND"])
    end

    it "requires a signed-in caller" do
      expect(error_codes(execute_graphql(query, variables: { id: email_log.id }))).to eq(["UNAUTHENTICATED"])
    end
  end
end
