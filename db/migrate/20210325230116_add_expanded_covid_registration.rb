class AddExpandedCovidRegistration < ActiveRecord::Migration[6.0]
  def change
    create_table :covid_vaccine_expanded_registration_submissions, id: :serial do |t|
      t.string "submission_uuid", null: false
      t.string "vetext_sid"
      t.boolean "sequestered", default: true, null: false
      t.string "state"
      t.string "email_confirmation_id"
      t.string "enrollment_id"
      t.string "batch_id"
      t.string "encrypted_raw_form_data"
      t.string "encrypted_raw_form_data_iv"
      t.string "encrypted_eligibility_info"
      t.string "encrypted_eligibility_info_iv"
      t.string "encrypted_form_data"
      t.string "encrypted_form_data_iv"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["submission_uuid"], name: "index_covid_vaccine_expanded_on_submission_id", unique: true
      t.index ["vetext_sid"], name: "index_covid_vaccine_expanded_on_vetext_sid", unique: true
      t.index ["encrypted_raw_form_data_iv"], name: "index_covid_vaccine_expanded_on_raw_iv", unique: true
      t.index ["encrypted_eligibility_info_iv"], name: "index_covid_vaccine_expanded_on_el_iv", unique: true
      t.index ["encrypted_form_data_iv"], name: "index_covid_vaccine_expanded_on_form_iv", unique: true
    end
  end
end