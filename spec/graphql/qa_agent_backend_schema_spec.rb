require "rails_helper"

RSpec.describe QaAgentBackendSchema do
  it "matches the committed schema.graphql (run bin/rails graphql:schema:idl after changing the API)" do
    expect(described_class.to_definition).to eq(Rails.root.join("schema.graphql").read)
  end
end
