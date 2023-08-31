class AddColumnPublicMetadataToForm5655Submissions < ActiveRecord::Migration[6.1]
  def change
    add_column :form5655_submissions, :public_metadata, :jsonb
  end
end
