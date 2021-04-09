class AddCovidVaccineExpandedStateIndex < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :covid_vaccine_expanded_registration_submissions, :state, algorithm: :concurrently
  end
end
