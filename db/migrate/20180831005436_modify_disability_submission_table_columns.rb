class ModifyDisabilitySubmissionTableColumns < ActiveRecord::Migration
  def change
    add_column(:disability_compensation_submissions, :disability_compensation_id, :integer)
    add_column(:disability_compensation_submissions, :async_transactions_id, :integer)

    remove_index(:disability_compensation_submissions, name: :index_disability_compensation_submissions_on_uuid_and_form_type, column: [:user_uuid, :form_type])
    remove_column(:disability_compensation_submissions, :job_id, :uuid)
    remove_column(:disability_compensation_submissions, :form_type, :string)
    remove_column(:disability_compensation_submissions, :status, :string)
    remove_column(:disability_compensation_submissions, :response, :json)
    remove_column(:disability_compensation_submissions, :user_uuid, :uuid)
  end
end
