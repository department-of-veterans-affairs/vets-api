class RemoveFieldsFromFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    remove_column :form_submissions, :submitted_claim_uuid, :uuid
    remove_reference :form_submissions, :in_progress_form, foreign_key: true
  end
end
