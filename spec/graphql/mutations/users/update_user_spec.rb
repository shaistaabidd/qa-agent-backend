require "rails_helper"

RSpec.describe "updateUser", type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation($id: ID, $attributes: UserAttributesInput!) {
        updateUser(input: { id: $id, userAttributes: $attributes }) { user { id firstName lastName } }
      }
    GQL
  end
  let(:user) { create(:user) }

  it "updates the caller's own profile and strips whitespace" do
    result = execute_graphql(mutation, variables: { attributes: { firstName: "  Jane ", lastName: "Doe" } }, as: user)

    expect(result.dig("data", "updateUser", "user")).to eq("id" => user.id.to_s, "firstName" => "Jane",
                                                           "lastName" => "Doe")
  end

  it "leaves omitted fields unchanged" do
    user.update!(last_name: "Doe")

    execute_graphql(mutation, variables: { attributes: { firstName: "Jane" } }, as: user)

    expect(user.reload.last_name).to eq("Doe")
  end

  it "lets a super admin update another user" do
    result = execute_graphql(mutation, variables: { id: user.id, attributes: { lastName: "Smith" } },
                                       as: create(:user, :super_admin))

    expect(result.dig("data", "updateUser", "user", "lastName")).to eq("Smith")
  end

  it "hides other users from a regular user" do
    other = create(:user)

    result = execute_graphql(mutation, variables: { id: other.id, attributes: { lastName: "Hacked" } }, as: user)

    expect(error_codes(result)).to eq(["NOT_FOUND"])
    expect(other.reload.last_name).not_to eq("Hacked")
  end

  it "does not accept an email change through updateUser" do
    result = execute_graphql(mutation, variables: { attributes: { email: "new@example.com" } }, as: user)

    expect(result.dig("errors", 0, "message")).to include("email")
    expect(user.reload.email).not_to eq("new@example.com")
  end

  it "requires a signed-in caller" do
    expect(error_codes(execute_graphql(mutation, variables: { attributes: { lastName: "Doe" } })))
      .to eq(["UNAUTHENTICATED"])
  end

  describe "profile image" do
    let(:upload_mutation) do
      <<~GQL
        mutation($image: Upload) { updateUser(input: { userAttributes: { image: $image } }) { user { imageUrl } } }
      GQL
    end
    let(:image) { graphql_upload("avatar.png", "image/png") }

    around do |example|
      ActiveStorage::Current.set(url_options: { host: "www.example.com" }) { example.run }
    end

    it "attaches an image and returns a signed URL" do
      result = execute_graphql(upload_mutation, variables: { image: }, as: user)

      expect(result.dig("data", "updateUser", "user", "imageUrl")).to be_present
      expect(user.reload.image).to be_attached
    end

    it "removes the image when null is sent" do
      user.image.attach(io: file_fixture("avatar.png").open, filename: "avatar.png")

      execute_graphql(upload_mutation, variables: { image: nil }, as: user)

      expect(user.reload.image).not_to be_attached
    end
  end
end
