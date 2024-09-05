class RemoveSubmittedClaimUuidIndexFromFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    remove_index :form_submissions, name: 'index_form_submissions_on_submitted_claim_uuid', if_exists: true
  end
end
