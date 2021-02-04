class AddColumnsForCovidAsyncSubmission < ActiveRecord::Migration[6.0]
  def change
    change_column_null :covid_vaccine_registration_submissions, :sid, true

    add_column :covid_vaccine_registration_submissions, :encrypted_raw_form_data, :string
    add_column :covid_vaccine_registration_submissions, :encrypted_raw_form_data_iv, :string
  end
end
