require "rails_helper"

RSpec.describe AttachGooglePictureJob do
  let(:user) { create(:user, google_uid: "google-uid-1") }
  let(:picture_url) { "https://lh3.googleusercontent.com/a/photo-id=s96-c" }

  def stub_picture(status: 200, body: file_fixture("avatar.png").binread, content_type: "image/png")
    stub_request(:get, picture_url).to_return(status:, body:, headers: { "Content-Type" => content_type })
  end

  it "copies the Google photo onto a user who has none" do
    stub_picture

    described_class.perform_now(user.id, picture_url)

    expect(user.reload.image).to be_attached
    expect(user.image.blob).to have_attributes(content_type: "image/png", byte_size: file_fixture("avatar.png").size)
  end

  it "never replaces a photo the user uploaded" do
    user.image.attach(io: file_fixture("avatar.png").open, filename: "mine.png", content_type: "image/png")

    described_class.perform_now(user.id, picture_url)

    expect(user.reload.image.filename.to_s).to eq("mine.png")
    expect(a_request(:get, picture_url)).not_to have_been_made
  end

  it "only fetches from Google's image hosts" do
    described_class.perform_now(user.id, "https://169.254.169.254/latest/meta-data")

    expect(user.reload.image).not_to be_attached
    expect(a_request(:get, /169\.254/)).not_to have_been_made
  end

  it "gives up quietly when Google won't serve the photo" do
    stub_picture(status: 404, body: "")

    expect { described_class.perform_now(user.id, picture_url) }.not_to raise_error
    expect(user.reload.image).not_to be_attached
  end

  it "keeps a file that isn't an allowed image type out" do
    stub_picture(body: "GIF89a", content_type: "image/gif")

    described_class.perform_now(user.id, picture_url)

    expect(user.reload.image).not_to be_attached
  end
end
