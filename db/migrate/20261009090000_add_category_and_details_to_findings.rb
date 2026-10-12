class AddCategoryAndDetailsToFindings < ActiveRecord::Migration[7.0]
  def change
    # category: error | network | performance. details: the worker's evidence —
    # stack trace, request/response, breadcrumbs, timings, occurrences.
    add_column :findings, :category, :string
    add_column :findings, :details, :jsonb, null: false, default: {}
  end
end
