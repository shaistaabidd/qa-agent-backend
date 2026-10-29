module Legacy
  # One-off import of the data of the app as it was before it moved onto the boilerplate (its own Postgres
  # database, the old schema) into this app's schema. Run it once, on a fresh database, between the first
  # deploy and the first sign-in. See docs/migrating-legacy-data.md.
  #
  # Rows keep their ids, so every foreign key and every Active Storage blob still lines up. The old users had
  # only an email and a bcrypt hash; the hash is kept (has_secure_password reads the same format), so people
  # keep their passwords, and they add their name through onboarding at the next sign-in. Role credentials are
  # copied as the ciphertext they already are: they stay readable only with the AR_ENCRYPTION_* keys they were
  # written with.
  #
  # Plain table models are used on both sides, so no callback, validation or encryption runs: it is a copy.
  class Import
    class TargetNotEmpty < StandardError; end
    class CountMismatch < StandardError; end

    TABLES = %w[users projects memberships integrations scope_features role_credentials runs audit_log_entries
                findings active_storage_blobs active_storage_attachments active_storage_variant_records].freeze
    BATCH_SIZE = 500

    # source_base: an abstract ActiveRecord class connected to the old database.
    # source_schema: only for specs, where the "old" tables live in a schema of the test database.
    def initialize(source_base:, source_schema: nil)
      @source_base = source_base
      @source_schema = source_schema
    end

    # Returns the row count copied per table. Without apply: true everything is rolled back.
    def call(apply: false)
      counts = {}
      ActiveRecord::Base.transaction do
        ensure_target_empty!
        counts = copy_all
        backfill_finding_sources
        verify!(counts)
        raise ActiveRecord::Rollback unless apply

        reset_sequences
      end
      counts
    end

    private

    def copy_all
      counts = { "users" => copy_users }
      counts["projects"], repo_connections = copy_projects
      %w[memberships integrations].each { |table| counts[table] = copy(table) }
      link_repo_connections(repo_connections)
      (TABLES - counts.keys).each { |table| counts[table] = copy(table) }
      counts
    end

    def copy_users
      batches(source_model("users")) do |users|
        target_model("users").insert_all!(users.map do |user|
          { id: user.id, email: user.email, password_digest: user.encrypted_password, role: 0,
            email_verified_at: user.created_at, created_at: user.created_at, updated_at: user.updated_at }
        end)
      end
    end

    # projects.repo_connection_id and integrations.project_id point at each other, so projects go in first
    # without the link and the link is set once integrations exist. Returns the row count and the links.
    def copy_projects
      links = {}
      source = source_model("projects")
      columns = shared_columns("projects", source)
      total = batches(source) do |projects|
        rows = projects.map { |project| project.attributes.slice(*columns) }
        rows.each { |row| links[row["id"]] = row.delete("repo_connection_id") }
        target_model("projects").insert_all!(rows)
      end
      [total, links.compact]
    end

    def link_repo_connections(links)
      projects = target_model("projects")
      links.each do |project_id, integration_id|
        projects.where(id: project_id).update_all(repo_connection_id: integration_id)
      end
    end

    def copy(table)
      source = source_model(table)
      columns = shared_columns(table, source)
      batches(source) do |records|
        target_model(table).insert_all!(records.map { |record| record.attributes.slice(*columns) })
      end
    end

    def batches(source)
      total = 0
      source.find_in_batches(batch_size: BATCH_SIZE) do |records|
        yield records
        total += records.size
      end
      total
    end

    def shared_columns(table, source) = source.column_names & target_model(table).column_names

    # The old app computed a finding's source on the fly; this one stores it.
    def backfill_finding_sources
      Finding.find_each do |finding|
        finding.valid?
        finding.update_columns(source: finding.source)
      end
    end

    def verify!(counts)
      counts.each do |table, copied|
        in_target = target_model(table).count
        raise CountMismatch, "#{table}: copied #{copied}, found #{in_target}" unless in_target == copied
      end
    end

    def ensure_target_empty!
      filled = TABLES.select { |table| target_model(table).exists? }
      return if filled.empty?

      raise TargetNotEmpty, "Import into a fresh database; these tables already have rows: #{filled.join(", ")}"
    end

    def reset_sequences
      TABLES.each { |table| ActiveRecord::Base.connection.reset_pk_sequence!(table) }
    end

    def source_model(table)
      table_name = @source_schema ? "#{@source_schema}.#{table}" : table
      Class.new(@source_base) do
        self.table_name = table_name
        self.inheritance_column = nil
      end
    end

    def target_model(table)
      Class.new(ActiveRecord::Base) do
        self.table_name = table
        self.inheritance_column = nil
      end
    end
  end
end
