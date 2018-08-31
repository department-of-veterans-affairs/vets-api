class ModifyDisabilitySubmissionTableColumns < ActiveRecord::Migration
  def change
    add_column(:disability_compensation_submissions, :saved_claim_id, :integer)

    remove_index(:disability_compensation_submissions, name: :index_disability_compensation_submissions_on_uuid_and_form_type)
    remove_column(:disability_compensation_submissions, :form_type, :string)
    remove_column(:disability_compensation_submissions, :status, :string)
    remove_column(:disability_compensation_submissions, :response, :json)
    remove_column(:disability_compensation_submissions, :user_uuid, :uuid)
  end
end
