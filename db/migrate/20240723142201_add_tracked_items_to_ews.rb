class AddTrackedItemsToEws < ActiveRecord::Migration[7.1]
  def change
    add_column :claims_api_evidence_waiver_submissions, :tracked_items, :integer, default: [], array: true
  end
end
