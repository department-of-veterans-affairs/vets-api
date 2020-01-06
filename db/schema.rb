# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_01_06_171714) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "uuid-ossp"

  create_table "accounts", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "idme_uuid"
    t.string "icn"
    t.string "edipi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idme_uuid"], name: "index_accounts_on_idme_uuid", unique: true
    t.index ["uuid"], name: "index_accounts_on_uuid", unique: true
  end

  create_table "async_transactions", id: :serial, force: :cascade do |t|
    t.string "type"
    t.string "user_uuid"
    t.string "source_id"
    t.string "source"
    t.string "status"
    t.string "transaction_id"
    t.string "transaction_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_metadata"
    t.string "encrypted_metadata_iv"
    t.index ["source_id"], name: "index_async_transactions_on_source_id"
    t.index ["transaction_id", "source"], name: "index_async_transactions_on_transaction_id_and_source", unique: true
    t.index ["transaction_id"], name: "index_async_transactions_on_transaction_id"
    t.index ["user_uuid"], name: "index_async_transactions_on_user_uuid"
  end

  create_table "base_facilities", id: false, force: :cascade do |t|
    t.string "unique_id", null: false
    t.string "name", null: false
    t.string "facility_type", null: false
    t.string "classification"
    t.string "website"
    t.float "lat", null: false
    t.float "long", null: false
    t.jsonb "address"
    t.jsonb "phone"
    t.jsonb "hours"
    t.jsonb "services"
    t.jsonb "feedback"
    t.jsonb "access"
    t.string "fingerprint"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.geography "location", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.boolean "mobile"
    t.string "active_status"
    t.string "visn"
    t.index ["location"], name: "index_base_facilities_on_location", using: :gist
    t.index ["name"], name: "index_base_facilities_on_name", using: :gin
    t.index ["unique_id", "facility_type"], name: "index_base_facilities_on_unique_id_and_facility_type", unique: true
  end

  create_table "beta_registrations", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.string "feature", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_uuid", "feature"], name: "index_beta_registrations_on_user_uuid_and_feature", unique: true
  end

  create_table "central_mail_submissions", id: :serial, force: :cascade do |t|
    t.string "state", default: "pending", null: false
    t.integer "saved_claim_id", null: false
    t.index ["saved_claim_id"], name: "index_central_mail_submissions_on_saved_claim_id"
    t.index ["state"], name: "index_central_mail_submissions_on_state"
  end

  create_table "claims_api_auto_established_claims", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "status"
    t.string "encrypted_form_data"
    t.string "encrypted_form_data_iv"
    t.string "encrypted_auth_headers"
    t.string "encrypted_auth_headers_iv"
    t.integer "evss_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "md5"
    t.string "source"
    t.string "encrypted_file_data"
    t.string "encrypted_file_data_iv"
    t.string "encrypted_evss_response"
    t.string "encrypted_evss_response_iv"
  end

  create_table "claims_api_power_of_attorneys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.string "current_poa"
    t.string "encrypted_form_data"
    t.string "encrypted_form_data_iv"
    t.string "encrypted_auth_headers"
    t.string "encrypted_auth_headers_iv"
    t.string "encrypted_file_data"
    t.string "encrypted_file_data_iv"
    t.string "md5"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vbms_new_document_version_ref_id"
    t.string "vbms_document_series_ref_id"
    t.string "vbms_error_message"
    t.integer "vbms_upload_failure_count", default: 0
  end

  create_table "claims_api_supporting_documents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "encrypted_file_data", null: false
    t.string "encrypted_file_data_iv", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "auto_established_claim_id", null: false
  end

  create_table "disability_compensation_job_statuses", id: :serial, force: :cascade do |t|
    t.integer "disability_compensation_submission_id", null: false
    t.string "job_id", null: false
    t.string "job_class", null: false
    t.string "status", null: false
    t.string "error_message"
    t.datetime "updated_at", null: false
    t.index ["disability_compensation_submission_id"], name: "index_disability_compensation_job_statuses_on_dsc_id"
    t.index ["job_id"], name: "index_disability_compensation_job_statuses_on_job_id", unique: true
  end

  create_table "disability_compensation_submissions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "disability_compensation_id"
    t.integer "va526ez_submit_transaction_id"
    t.boolean "complete", default: false
  end

  create_table "disability_contentions", id: :serial, force: :cascade do |t|
    t.integer "code", null: false
    t.string "medical_term", null: false
    t.string "lay_term"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_disability_contentions_on_code", unique: true
    t.index ["lay_term"], name: "index_disability_contentions_on_lay_term", using: :gin
    t.index ["medical_term"], name: "index_disability_contentions_on_medical_term", using: :gin
  end

  create_table "drivetime_bands", force: :cascade do |t|
    t.string "name"
    t.string "unit"
    t.geography "polygon", limit: {:srid=>4326, :type=>"st_polygon", :geographic=>true}, null: false
    t.string "vha_facility_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "min"
    t.integer "max"
    t.index ["polygon"], name: "index_drivetime_bands_on_polygon", using: :gist
  end

  create_table "education_benefits_claims", id: :serial, force: :cascade do |t|
    t.datetime "submitted_at"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_form"
    t.string "encrypted_form_iv"
    t.string "regional_processing_office", null: false
    t.string "form_type", default: "1990"
    t.integer "saved_claim_id", null: false
    t.index ["created_at"], name: "index_education_benefits_claims_on_created_at"
    t.index ["saved_claim_id"], name: "index_education_benefits_claims_on_saved_claim_id"
    t.index ["submitted_at"], name: "index_education_benefits_claims_on_submitted_at"
  end

  create_table "education_benefits_submissions", id: :serial, force: :cascade do |t|
    t.string "region", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "chapter33", default: false, null: false
    t.boolean "chapter30", default: false, null: false
    t.boolean "chapter1606", default: false, null: false
    t.boolean "chapter32", default: false, null: false
    t.string "status", default: "submitted", null: false
    t.integer "education_benefits_claim_id"
    t.string "form_type", default: "1990", null: false
    t.boolean "chapter35", default: false, null: false
    t.boolean "transfer_of_entitlement", default: false, null: false
    t.boolean "chapter1607", default: false, null: false
    t.boolean "vettec", default: false
    t.index ["education_benefits_claim_id"], name: "index_education_benefits_claim_id", unique: true
    t.index ["region", "created_at", "form_type"], name: "index_edu_benefits_subs_ytd"
  end

  create_table "evss_claims", id: :serial, force: :cascade do |t|
    t.integer "evss_id", null: false
    t.json "data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_uuid", null: false
    t.json "list_data", default: {}, null: false
    t.boolean "requested_decision", default: false, null: false
    t.index ["user_uuid"], name: "index_evss_claims_on_user_uuid"
  end

  create_table "feature_toggle_events", force: :cascade do |t|
    t.string "feature_name"
    t.string "operation"
    t.string "gate_name"
    t.string "value"
    t.string "user"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_name"], name: "index_feature_toggle_events_on_feature_name"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "form526_job_statuses", id: :serial, force: :cascade do |t|
    t.integer "form526_submission_id", null: false
    t.string "job_id", null: false
    t.string "job_class", null: false
    t.string "status", null: false
    t.string "error_class"
    t.string "error_message"
    t.datetime "updated_at", null: false
    t.index ["form526_submission_id"], name: "index_form526_job_statuses_on_form526_submission_id"
    t.index ["job_id"], name: "index_form526_job_statuses_on_job_id", unique: true
  end

  create_table "form526_opt_ins", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.string "encrypted_email", null: false
    t.string "encrypted_email_iv", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_uuid"], name: "index_form526_opt_ins_on_user_uuid", unique: true
  end

  create_table "form526_submissions", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.integer "saved_claim_id", null: false
    t.integer "submitted_claim_id"
    t.string "encrypted_auth_headers_json", null: false
    t.string "encrypted_auth_headers_json_iv", null: false
    t.string "encrypted_form_json", null: false
    t.string "encrypted_form_json_iv", null: false
    t.boolean "workflow_complete", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["saved_claim_id"], name: "index_form526_submissions_on_saved_claim_id", unique: true
    t.index ["submitted_claim_id"], name: "index_form526_submissions_on_submitted_claim_id", unique: true
    t.index ["user_uuid"], name: "index_form526_submissions_on_user_uuid"
  end

  create_table "form_attachments", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "guid", null: false
    t.string "encrypted_file_data", null: false
    t.string "encrypted_file_data_iv", null: false
    t.string "type", null: false
    t.index ["guid", "type"], name: "index_form_attachments_on_guid_and_type", unique: true
  end

  create_table "gibs_not_found_users", id: :serial, force: :cascade do |t|
    t.string "edipi", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "encrypted_ssn", null: false
    t.string "encrypted_ssn_iv", null: false
    t.datetime "dob", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edipi"], name: "index_gibs_not_found_users_on_edipi"
  end

  create_table "health_care_applications", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "pending", null: false
    t.string "form_submission_id_string"
    t.string "timestamp"
  end

  create_table "id_card_announcement_subscriptions", id: :serial, force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_id_card_announcement_subscriptions_on_email", unique: true
  end

  create_table "in_progress_forms", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.string "form_id", null: false
    t.string "encrypted_form_data", null: false
    t.string "encrypted_form_data_iv", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "metadata"
    t.datetime "expires_at"
    t.index ["form_id", "user_uuid"], name: "index_in_progress_forms_on_form_id_and_user_uuid", unique: true
  end

  create_table "invalid_letter_address_edipis", id: :serial, force: :cascade do |t|
    t.string "edipi", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edipi"], name: "index_invalid_letter_address_edipis_on_edipi"
  end

  create_table "maintenance_windows", id: :serial, force: :cascade do |t|
    t.string "pagerduty_id"
    t.string "external_service"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_time"], name: "index_maintenance_windows_on_end_time"
    t.index ["pagerduty_id"], name: "index_maintenance_windows_on_pagerduty_id"
    t.index ["start_time"], name: "index_maintenance_windows_on_start_time"
  end

  create_table "mhv_accounts", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.string "account_state", null: false
    t.datetime "registered_at"
    t.datetime "upgraded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mhv_correlation_id"
    t.index ["user_uuid", "mhv_correlation_id"], name: "index_mhv_accounts_on_user_uuid_and_mhv_correlation_id", unique: true
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "subject", null: false
    t.integer "status"
    t.datetime "status_effective_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "subject"], name: "index_notifications_on_account_id_and_subject", unique: true
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["status"], name: "index_notifications_on_status"
    t.index ["subject"], name: "index_notifications_on_subject"
  end

  create_table "persistent_attachments", id: :serial, force: :cascade do |t|
    t.uuid "guid"
    t.string "type"
    t.string "form_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "saved_claim_id"
    t.datetime "completed_at"
    t.string "encrypted_file_data", null: false
    t.string "encrypted_file_data_iv", null: false
    t.index ["guid"], name: "index_persistent_attachments_on_guid", unique: true
    t.index ["saved_claim_id"], name: "index_persistent_attachments_on_saved_claim_id"
  end

  create_table "personal_information_logs", id: :serial, force: :cascade do |t|
    t.jsonb "data", null: false
    t.string "error_class", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_personal_information_logs_on_created_at"
    t.index ["error_class"], name: "index_personal_information_logs_on_error_class"
  end

  create_table "preference_choices", id: :serial, force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.integer "preference_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["preference_id"], name: "index_preference_choices_on_preference_id"
  end

  create_table "preferences", id: :serial, force: :cascade do |t|
    t.string "code", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_preferences_on_code", unique: true
  end

  create_table "preneed_submissions", id: :serial, force: :cascade do |t|
    t.string "tracking_number", null: false
    t.string "application_uuid"
    t.string "return_description", null: false
    t.integer "return_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_uuid"], name: "index_preneed_submissions_on_application_uuid", unique: true
    t.index ["tracking_number"], name: "index_preneed_submissions_on_tracking_number", unique: true
  end

  create_table "saved_claims", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "encrypted_form", null: false
    t.string "encrypted_form_iv", null: false
    t.string "form_id"
    t.uuid "guid", null: false
    t.string "type"
    t.index ["created_at", "type"], name: "index_saved_claims_on_created_at_and_type"
    t.index ["guid"], name: "index_saved_claims_on_guid", unique: true
  end

  create_table "session_activities", id: :serial, force: :cascade do |t|
    t.uuid "originating_request_id", null: false
    t.string "originating_ip_address", null: false
    t.text "generated_url", null: false
    t.string "name", null: false
    t.string "status", default: "incomplete", null: false
    t.uuid "user_uuid"
    t.string "sign_in_service_name"
    t.string "sign_in_account_type"
    t.boolean "multifactor_enabled"
    t.boolean "idme_verified"
    t.integer "duration"
    t.jsonb "additional_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_session_activities_on_name"
    t.index ["status"], name: "index_session_activities_on_status"
    t.index ["user_uuid"], name: "index_session_activities_on_user_uuid"
  end

  create_table "terms_and_conditions", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "title"
    t.text "terms_content"
    t.text "header_content"
    t.string "yes_content"
    t.string "no_content"
    t.string "footer_content"
    t.string "version"
    t.boolean "latest", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name", "latest"], name: "index_terms_and_conditions_on_name_and_latest"
  end

  create_table "terms_and_conditions_acceptances", id: false, force: :cascade do |t|
    t.string "user_uuid"
    t.integer "terms_and_conditions_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_uuid"], name: "index_terms_and_conditions_acceptances_on_user_uuid"
  end

  create_table "user_preferences", id: :serial, force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "preference_id", null: false
    t.integer "preference_choice_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_user_preferences_on_account_id"
    t.index ["preference_choice_id"], name: "index_user_preferences_on_preference_choice_id"
    t.index ["preference_id"], name: "index_user_preferences_on_preference_id"
  end

  create_table "va_forms_forms", force: :cascade do |t|
    t.string "form_name"
    t.string "url"
    t.string "title"
    t.date "first_issued_on"
    t.date "last_revision_on"
    t.integer "pages"
    t.string "sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vba_documents_upload_submissions", id: :serial, force: :cascade do |t|
    t.uuid "guid", null: false
    t.string "status", default: "pending", null: false
    t.string "code"
    t.string "detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "s3_deleted"
    t.string "consumer_name"
    t.uuid "consumer_id"
    t.index ["guid"], name: "index_vba_documents_upload_submissions_on_guid"
    t.index ["status"], name: "index_vba_documents_upload_submissions_on_status"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "veteran_organizations", id: false, force: :cascade do |t|
    t.string "poa", limit: 3
    t.string "name"
    t.string "phone"
    t.string "state", limit: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["poa"], name: "index_veteran_organizations_on_poa", unique: true
  end

  create_table "veteran_representatives", id: false, force: :cascade do |t|
    t.string "representative_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_ssn"
    t.string "encrypted_ssn_iv"
    t.string "encrypted_dob"
    t.string "encrypted_dob_iv"
    t.string "poa_codes", default: [], array: true
    t.string "user_types", default: [], array: true
    t.index ["representative_id", "first_name", "last_name"], name: "index_vso_grp", unique: true
  end

  create_table "vic_submissions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "pending", null: false
    t.uuid "guid", null: false
    t.json "response"
    t.index ["guid"], name: "index_vic_submissions_on_guid", unique: true
  end

end
