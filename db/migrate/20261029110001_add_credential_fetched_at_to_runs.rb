class AddCredentialFetchedAtToRuns < ActiveRecord::Migration[8.1]
  def change
    # Set when the worker exchanges its fetch token for the credential, so a token works once.
    add_column :runs, :credential_fetched_at, :datetime
  end
end
