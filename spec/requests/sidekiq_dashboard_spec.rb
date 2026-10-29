require "rails_helper"

RSpec.describe "Sidekiq dashboard" do
  def basic(username, password)
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) }
  end

  context "with dashboard credentials configured" do
    before do
      stub_const("FlipperUi::USERNAME", "ops")
      stub_const("FlipperUi::PASSWORD", "s3cret")
    end

    it "refuses a request without credentials" do
      get "/sidekiq/"

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses wrong credentials" do
      get "/sidekiq/", headers: basic("ops", "wrong")

      expect(response).to have_http_status(:unauthorized)
    end

    it "serves the dashboard with the right ones" do
      get "/sidekiq/", headers: basic("ops", "s3cret")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sidekiq")
    end
  end

  context "without credentials configured (development)" do
    it "serves the dashboard" do
      stub_const("FlipperUi::USERNAME", nil)
      stub_const("FlipperUi::PASSWORD", nil)

      get "/sidekiq/"

      expect(response).to have_http_status(:ok)
    end
  end
end
