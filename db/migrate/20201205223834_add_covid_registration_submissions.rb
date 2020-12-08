class AddCovidRegistrationSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :covid_vaccine_registration_submissions, id: :serial do |t|
      t.string "sid", null: false
      t.uuid "account_id", null: true
      t.string "encrypted_form_data"
      t.string "encrypted_form_data_iv"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["sid"], name: "index_covid_vaccine_registry_submissions_on_sid", unique: true
      t.index ["encrypted_form_data_iv"], name: "index_covid_vaccine_registry_submissions_on_iv", unique: true
      t.index ["account_id", "created_at"], name: "index_covid_vaccine_registry_submissions_2"
    end
  end
end
