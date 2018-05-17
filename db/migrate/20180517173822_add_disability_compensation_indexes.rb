class AddDisabilityCompensationIndexes < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :disability_compensation_submissions, [:user_uuid, :form_type], \
      name: 'index_disability_compensation_submissions_on_uuid_and_form_type', unique: true, algorithm: :concurrently
    add_index :disability_compensation_submissions, :claim_id, unique: true, algorithm: :concurrently
  end
end
