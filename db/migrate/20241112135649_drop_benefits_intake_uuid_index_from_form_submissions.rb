class DropBenefitsIntakeUuidIndexFromFormSubmissions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  
  def change
    remove_index :form_submissions, name: 'index_form_submissions_on_benefits_intake_uuid', if_exists: true
  end
end
