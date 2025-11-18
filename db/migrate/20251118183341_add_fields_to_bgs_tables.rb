class AddFieldsToBGSTables < ActiveRecord::Migration[7.2]
  def change
    add_column :bgs_submission_attempts, :claim_type_end_product, :string, null: true
    add_column :bgs_submissions, :proc_id, :string, null: true
  end
end
