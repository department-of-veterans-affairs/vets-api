class AddCovidRegistrationSubmissions < ActiveRecord::Migration[6.0]
  def change
    create_table :covid_vaccine_registration_submissions, id: :serial do |t|
      t.string "sid", null: false
      t.integer "account_id", null: true
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["sid"], name: "index_covid_vaccine_registry_submissions_on_sid", unique: true
      t.index ["account_id", "created_at"], name: "index_covid_vaccine_registry_submissions_2"
    end
  end
end
