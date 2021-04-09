class AddCovidVaccineExpandedBatchIdIndex < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  
  def change
    add_index :covid_vaccine_expanded_registration_submissions, :batch_id,
      algorithm: :concurrently, name: :index_covid_vaccine_expanded_reg_submissions_on_batch_id
  end
end
