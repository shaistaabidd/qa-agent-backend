require "rails_helper"

RSpec.describe "SMS log queries", type: :graphql do
  let(:admin) { create(:user, :super_admin) }
  let(:user) { create(:user, email: "ada@example.com", first_name: "Ada", last_name: "Lovelace") }

  describe "allSmsLogs" do
    let(:query) do
      <<~GQL
        query($filter: SmsLogFilterInput) {
          allSmsLogs(filter: $filter) { count totalPages allData { recipient status messageType } }
        }
      GQL
    end

    def recipients(filter = {})
      execute_graphql(query, variables: { filter: }, as: admin).dig("data", "allSmsLogs", "allData").pluck("recipient")
    end

    it "returns the newest first with every field the admin page shows" do
      create(:sms_log, :failed, user:, recipient: "+12015550111", created_at: 1.day.ago)
      create(:sms_log, :queued, recipient: "+12015550122")
      fields = "id recipient body messageType status providerSid errorCode errorMessage sentAt " \
               "createdAt updatedAt user { id email firstName lastName }"

      rows = execute_graphql("{ allSmsLogs { allData { #{fields} } } }", as: admin).dig("data", "allSmsLogs", "allData")

      expect(rows.pluck("recipient")).to eq(%w[+12015550122 +12015550111])
      expect(rows.last).to include("status" => "FAILED", "messageType" => "WELCOME", "errorCode" => "21211",
                                   "errorMessage" => "The phone number is not valid.",
                                   "user" => { "id" => user.id.to_s, "email" => "ada@example.com",
                                               "firstName" => "Ada", "lastName" => "Lovelace" })
    end

    context "with two messages" do
      before do
        create(:sms_log, recipient: "+12015550111", body: "Welcome Ada", created_at: Time.zone.local(2026, 10, 2, 12))
        create(:sms_log, :queued, recipient: "+12015550122", body: "Welcome Grace",
                                  created_at: Time.zone.local(2026, 10, 3, 12))
      end

      it "filters by status, type and day" do
        expect(recipients(status: "QUEUED")).to eq(["+12015550122"])
        expect(recipients(messageType: "WELCOME").size).to eq(2)
        expect(recipients(startDate: "2026-10-03")).to eq(["+12015550122"])
      end

      it "searches the number and the text, treating % literally" do
        expect(recipients(search: "grace")).to eq(["+12015550122"])
        expect(recipients(search: "0111")).to eq(["+12015550111"])
        expect(recipients(search: "%")).to be_empty
      end
    end

    it "loads the recipient accounts without N+1 queries" do
      create_list(:sms_log, 3)
      Bullet.start_request

      execute_graphql("{ allSmsLogs { allData { user { email } } } }", as: admin)

      expect(Bullet.notification?).to be(false)
    ensure
      Bullet.end_request
    end

    it "still lists an SMS whose user was deleted" do
      create(:sms_log, user:)
      user.destroy!

      result = execute_graphql("{ allSmsLogs { allData { user { id } } } }", as: admin)

      expect(result.dig("data", "allSmsLogs", "allData")).to eq([{ "user" => nil }])
    end

    it "is only for super admins" do
      expect(error_codes(execute_graphql(query, as: user))).to eq(["FORBIDDEN"])
    end

    it "requires a signed-in caller" do
      expect(error_codes(execute_graphql(query))).to eq(["UNAUTHENTICATED"])
    end
  end

  describe "fetchSmsLog" do
    let(:query) { "query($id: ID!) { fetchSmsLog(id: $id) { id body status } }" }
    let(:sms_log) { create(:sms_log, :queued, body: "Welcome!") }

    it "returns one SMS" do
      expect(execute_graphql(query, variables: { id: sms_log.id }, as: admin).dig("data", "fetchSmsLog"))
        .to eq("id" => sms_log.id.to_s, "body" => "Welcome!", "status" => "QUEUED")
    end

    it "is only for super admins" do
      expect(error_codes(execute_graphql(query, variables: { id: sms_log.id }, as: user))).to eq(["FORBIDDEN"])
    end

    it "returns NOT_FOUND for an unknown id" do
      expect(error_codes(execute_graphql(query, variables: { id: 0 }, as: admin))).to eq(["NOT_FOUND"])
    end
  end
end
