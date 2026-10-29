require "rails_helper"

# Flipper's Rails engine wraps every request in Flipper::Middleware::Memoizer
# with preloading on, so flags are read from storage (Redis in production) once
# per request instead of once per flag per user row. This guards that: a users
# list asks for every row's featureFlags.
RSpec.describe "Feature flag storage reads per request" do
  let(:admin) { create(:user, :super_admin) }
  let(:query) { { query: "{ allUsers(filters: { perPage: 10 }) { allData { id featureFlags { #{flag_fields} } } } }" } }
  let(:flag_fields) { FeatureFlag::NAMES.map { it.to_s.camelize(:lower) }.join(" ") }

  def storage
    adapter = Flipper.instance.adapter
    adapter = adapter.adapter while adapter.respond_to?(:adapter)
    adapter
  end

  def count_storage_reads
    reads = Hash.new(0)
    %i[get get_multi get_all].each do |method|
      allow(storage).to receive(method).and_wrap_original do |original, *args|
        reads[method] += 1
        original.call(*args)
      end
    end
    yield
    reads
  end

  before { create_list(:user, 10) }

  it "reads every flag in one storage call for a whole users list" do
    reads = count_storage_reads do
      post "/graphql", params: query.to_json,
                       headers: { "Content-Type" => "application/json",
                                  "Authorization" => "Bearer #{create(:session, user: admin).token}" }
    end

    expect(response.parsed_body.dig("data", "allUsers", "allData").size).to eq(10)
    expect(reads).to eq(get_all: 1)
  end

  it "would read once per flag per user without it" do
    reads = count_storage_reads { User.user.limit(10).each { FeatureFlag.values_for(it) } }

    expect(reads[:get]).to eq(10 * FeatureFlag::NAMES.size)
  end
end
