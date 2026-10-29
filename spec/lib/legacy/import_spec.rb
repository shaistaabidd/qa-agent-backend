require "rails_helper"

RSpec.describe Legacy::Import do
  let(:connection) { ActiveRecord::Base.connection }
  let(:source_base) { Class.new(ApplicationRecord) { self.abstract_class = true } }
  let(:import) { described_class.new(source_base:, source_schema: "legacy") }
  let(:old_hash) { BCrypt::Password.create("admin123").to_s }

  # The old app's database, as a schema next to the real one: the domain tables have the same columns as
  # today's, users has the old Devise shape and findings has no stored source.
  before do
    connection.execute("CREATE SCHEMA legacy")
    (described_class::TABLES - %w[users]).each do |table|
      connection.execute("CREATE TABLE legacy.#{table} (LIKE public.#{table} INCLUDING DEFAULTS INCLUDING INDEXES)")
    end
    connection.execute("ALTER TABLE legacy.findings DROP COLUMN source")
    connection.execute(<<~SQL.squish)
      CREATE TABLE legacy.users (id bigint PRIMARY KEY, email varchar NOT NULL, encrypted_password varchar NOT NULL,
        reset_password_token varchar, created_at timestamp NOT NULL, updated_at timestamp NOT NULL)
    SQL

    seed_old_data
  end

  def seed_old_data
    seed_old_accounts
    seed_old_runs
  end

  def seed_old_accounts
    connection.execute(<<~SQL.squish)
      INSERT INTO legacy.users (id, email, encrypted_password, created_at, updated_at)
        VALUES (7, 'ada@example.test', '#{old_hash}', '2026-01-01', '2026-01-02');
      INSERT INTO legacy.projects (id, name, target_url, repo_connection_id, created_at, updated_at)
        VALUES (3, 'Shop', 'https://shop.example.test', 9, now(), now()),
               (2, 'Blog', 'https://blog.example.test', NULL, now(), now());
      INSERT INTO legacy.integrations (id, project_id, integration_type, external_account_id, connected_at, created_at, updated_at)
        VALUES (9, 3, 0, 'acct-1', now(), now(), now());
      INSERT INTO legacy.memberships (id, user_id, project_id, role, created_at, updated_at)
        VALUES (4, 7, 3, 1, now(), now());
      INSERT INTO legacy.scope_features (id, project_id, name, route, source, approved, created_at, updated_at)
        VALUES (5, 3, 'Checkout', 'checkout', 'routes.rb', true, now(), now());
    SQL
  end

  def seed_old_runs
    connection.execute(<<~SQL.squish)
      INSERT INTO legacy.role_credentials (id, project_id, role_name, encrypted_credential_ref, created_at, updated_at)
        VALUES (6, 3, 'admin', '{"p":"ciphertext"}', now(), now());
      INSERT INTO legacy.runs (id, project_id, scope_feature_id, role_name, status, summary, created_at, updated_at)
        VALUES (8, 3, 5, 'admin', 3, '{"pages": 12}', now(), now());
      INSERT INTO legacy.findings (id, run_id, title, repro_steps, severity, category, details, created_at, updated_at)
        VALUES (11, 8, 'Slow query', '["open"]', 1, 'performance', '{"type": "slow_query"}', now(), now()),
               (12, 8, 'Blank screen', '[]', 2, NULL, '{}', now(), now());
    SQL
  end

  it "copies every table, keeping ids" do
    counts = import.call(apply: true)

    expect(counts).to include("users" => 1, "projects" => 2, "memberships" => 1, "integrations" => 1,
                              "scope_features" => 1, "role_credentials" => 1, "runs" => 1, "findings" => 2)
    expect(Project.find(3)).to have_attributes(name: "Shop", target_url: "https://shop.example.test")
    expect(Membership.find(4)).to have_attributes(user_id: 7, project_id: 3, role: "admin")
    expect(Run.find(8)).to have_attributes(status: "completed", summary: { "pages" => 12 })
  end

  it "keeps users' passwords and makes them able to sign in" do
    import.call(apply: true)

    user = User.find(7)
    expect(user.password_digest).to eq(old_hash)
    expect(user.authenticate("admin123")).to be_truthy
    expect(user).to have_attributes(role: "user", email_verified_at: Time.utc(2026, 1, 1), first_name: nil)
  end

  it "restores the project's repository link after the integrations exist" do
    import.call(apply: true)

    expect(Project.find(3).repo_connection_id).to eq(9)
    expect(Project.find(2).repo_connection_id).to be_nil
  end

  it "stores the source of each finding" do
    import.call(apply: true)

    expect(Finding.find(11).source).to eq("backend")
    expect(Finding.find(12).source).to eq("frontend")
  end

  it "copies role credentials as the ciphertext they already are" do
    import.call(apply: true)

    raw = connection.select_value("SELECT encrypted_credential_ref FROM public.role_credentials WHERE id = 6")
    expect(raw).to eq('{"p":"ciphertext"}')
  end

  it "lets new rows follow the imported ids" do
    import.call(apply: true)

    expect(create(:user).id).to be > 7
    expect(create(:project).id).to be > 3
  end

  it "writes nothing in a dry run" do
    counts = import.call

    expect(counts["users"]).to eq(1)
    expect(User.count).to eq(0)
    expect(Project.count).to eq(0)
  end

  it "refuses a database that already has data" do
    create(:user)

    expect { import.call(apply: true) }.to raise_error(described_class::TargetNotEmpty, /users/)
    expect(Project.count).to eq(0)
  end

  it "writes nothing when the copy doesn't add up" do
    allow(import).to receive(:verify!).and_raise(described_class::CountMismatch, "users: copied 1, found 0")

    expect { import.call(apply: true) }.to raise_error(described_class::CountMismatch)
    expect(User.count).to eq(0)
  end
end
