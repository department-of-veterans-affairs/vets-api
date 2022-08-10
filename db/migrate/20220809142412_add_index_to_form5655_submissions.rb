class AddIndexToForm5655Submissions < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  
  def change
    add_index :form5655_submissions, :user_uuid, algorithm: :concurrently
  end
end
