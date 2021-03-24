class AddVaccineExpansionFields < ActiveRecord::Migration[6.0]
  def change
    add_column :covid_vaccine_registration_submissions, :expanded, :boolean, default: false, null: false
    add_column :covid_vaccine_registration_submissions, :sequestered, :boolean, default: false, null: false
    add_column :covid_vaccine_registration_submissions, :email_confirmation_id, :string
    add_column :covid_vaccine_registration_submissions, :enrollment_id, :string
  end
end
