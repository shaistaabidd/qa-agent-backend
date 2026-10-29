namespace :legacy do
  desc "Import the pre-boilerplate app's data: LEGACY_DATABASE_URL=<old db>, APPLY=1 to write (default: dry run)"
  task import: :environment do
    url = ENV["LEGACY_DATABASE_URL"].presence || abort("Set LEGACY_DATABASE_URL to the old app's database URL")
    apply = ENV["APPLY"] == "1"

    # The old database is only ever read: every transaction on this connection is read-only.
    Legacy::Source.establish_connection(url:, variables: { default_transaction_read_only: "on" })

    counts = Legacy::Import.new(source_base: Legacy::Source).call(apply:)
    puts(counts.map { |table, rows| "#{table.ljust(32)} #{rows}" })
    puts apply ? "Imported." : "Dry run: nothing was written. Run again with APPLY=1 to import."
  rescue Legacy::Import::TargetNotEmpty, Legacy::Import::CountMismatch => e
    abort e.message
  end
end
