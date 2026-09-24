class RemoveScreenshotRefFromFindings < ActiveRecord::Migration[7.0]
  def change
    # Superseded by has_one_attached :screenshot (ActiveStorage) — evidence
    # is now stored as a real attachment instead of a bare string reference.
    remove_column :findings, :screenshot_ref, :string
  end
end
