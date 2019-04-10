class ModifyDisabilitySubmissionTableColumns < ActiveRecord::Migration[4.2]
  def change
    add_column(:disability_compensation_submissions, :disability_compensation_id, :integer)
    add_column(:disability_compensation_submissions, :va526ez_submit_transaction_id, :integer)

    remove_index(:disability_compensation_submissions, name: :index_disability_compensation_submissions_on_uuid_and_form_type, column: [:user_uuid, :form_type])
    remove_column(:disability_compensation_submissions, :form_type, :string, null: false)
    remove_column(:disability_compensation_submissions, :claim_id, :integer, null: false, unique: true)
    remove_column(:disability_compensation_submissions, :user_uuid, :uuid, null: false)
  end
end
