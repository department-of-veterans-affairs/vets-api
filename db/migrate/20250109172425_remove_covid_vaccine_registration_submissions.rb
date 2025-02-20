class RemoveCovidVaccineRegistrationSubmissions < ActiveRecord::Migration[7.2]
  def up
    drop_table :covid_vaccine_expanded_registration_submissions, if_exists: true
    drop_table :covid_vaccine_registration_submissions, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
