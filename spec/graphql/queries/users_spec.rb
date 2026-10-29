require "rails_helper"

RSpec.describe "User queries", type: :graphql do
  let(:admin) { create(:user, :super_admin) }

  describe "fetchUser" do
    let(:query) do
      <<~GQL
        query($id: ID) { fetchUser(id: $id) { id email role } }
      GQL
    end
    let(:user) { create(:user) }

    it "returns the signed-in user when no id is given" do
      expect(execute_graphql(query, as: user).dig("data", "fetchUser", "id")).to eq(user.id.to_s)
    end

    it "lets a super admin fetch anyone" do
      expect(execute_graphql(query, variables: { id: user.id }, as: admin).dig("data", "fetchUser", "email"))
        .to eq(user.email)
    end

    it "hides another user from a regular user" do
      expect(error_codes(execute_graphql(query, variables: { id: admin.id }, as: user))).to eq(["NOT_FOUND"])
    end

    it "requires a signed-in caller" do
      expect(error_codes(execute_graphql(query))).to eq(["UNAUTHENTICATED"])
    end
  end

  describe "allUsers" do
    let(:query) do
      <<~GQL
        query($filters: UserFilterInput) {
          allUsers(filters: $filters) {
            count currentPage totalPages nextPage prevPage
            allData { email }
          }
        }
      GQL
    end

    def emails(filters = {})
      execute_graphql(query, variables: { filters: }, as: admin).dig("data", "allUsers", "allData").pluck("email")
    end

    it "is only for super admins" do
      expect(error_codes(execute_graphql(query, as: create(:user)))).to eq(["FORBIDDEN"])
    end

    it "filters by role, invitation, archive and access status" do
      create(:user, email: "active@example.com")
      create(:user, :invited, email: "pending@example.com")
      create(:user, :archived, email: "archived@example.com")
      create(:user, :access_revoked, email: "revoked@example.com")

      expect(emails(role: "user", pending: false, archived: false, status: "active")).to eq(["active@example.com"])
      expect(emails(role: "user", pending: true)).to eq(["pending@example.com"])
      expect(emails(role: "user", archived: true)).to eq(["archived@example.com"])
      expect(emails(role: "user", status: "inactive")).to eq(["revoked@example.com"])
    end

    it "searches names and emails, treating % and _ literally" do
      create(:user, email: "jane@example.com", first_name: "Jane", last_name: "Doe")
      create(:user, email: "john@example.com")

      expect(emails(search: "jane doe")).to eq(["jane@example.com"])
      expect(emails(search: "%")).to be_empty
    end

    it "loads profile images without N+1 queries when imageUrl is selected" do
      create_list(:user, 2).each { it.image.attach(io: file_fixture("avatar.png").open, filename: "avatar.png") }
      Bullet.start_request

      ActiveStorage::Current.set(url_options: { host: "www.example.com" }) do
        execute_graphql("{ allUsers { allData { imageUrl } } }", as: admin)
      end

      expect(Bullet.notification?).to be(false)
    ensure
      Bullet.end_request
    end

    it "does not preload images when imageUrl is not selected" do
      create(:user).image.attach(io: file_fixture("avatar.png").open, filename: "avatar.png")
      Bullet.start_request

      execute_graphql(query, as: admin)

      expect(Bullet.notification?).to be(false)
    ensure
      Bullet.end_request
    end

    it "paginates and caps the page size" do
      create_list(:user, 3)

      page = execute_graphql(query, variables: { filters: { perPage: 2, page: 2 } }, as: admin).dig("data", "allUsers")

      expect(page).to include("count" => 4, "currentPage" => 2, "totalPages" => 2, "nextPage" => nil,
                              "prevPage" => 1)
      expect(page["allData"].size).to eq(2)
    end

    it "never returns more than the maximum page size" do
      User.insert_all(Array.new(Pagy::OPTIONS[:client_limit] + 1) { { email: "bulk#{it}@example.com" } })

      result = execute_graphql(query, variables: { filters: { perPage: 10_000 } }, as: admin)

      expect(result.dig("data", "allUsers", "allData").size).to eq(Pagy::OPTIONS[:client_limit])
    end
  end
end
