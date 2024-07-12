class RemoveFieldsFromFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :form_submissions, :submitted_claim_uuid, :uuid }
    safety_assured { remove_reference :form_submissions, :in_progress_form, foreign_key: true }
  end
end
