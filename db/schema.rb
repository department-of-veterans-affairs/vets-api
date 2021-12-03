# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_12_03_132446) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "uuid-ossp"

  create_table "account_login_stats", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "idme_at"
    t.datetime "myhealthevet_at"
    t.datetime "dslogon_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "current_verification"
    t.datetime "logingov_at"
    t.index ["account_id"], name: "index_account_login_stats_on_account_id", unique: true
    t.index ["current_verification"], name: "index_account_login_stats_on_current_verification"
    t.index ["dslogon_at"], name: "index_account_login_stats_on_dslogon_at"
    t.index ["idme_at"], name: "index_account_login_stats_on_idme_at"
    t.index ["logingov_at"], name: "index_account_login_stats_on_logingov_at"
    t.index ["myhealthevet_at"], name: "index_account_login_stats_on_myhealthevet_at"
  end

  create_table "accounts", id: :serial, force: :cascade do |t|
    t.uuid "uuid", null: false
    t.string "idme_uuid"
    t.string "icn"
    t.string "edipi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sec_id"
    t.string "logingov_uuid"
    t.index ["icn"], name: "index_accounts_on_icn"
    t.index ["idme_uuid"], name: "index_accounts_on_idme_uuid", unique: true
    t.index ["logingov_uuid"], name: "index_accounts_on_logingov_uuid", unique: true
    t.index ["sec_id"], name: "index_accounts_on_sec_id"
    t.index ["uuid"], name: "index_accounts_on_uuid", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appeal_submission_uploads", force: :cascade do |t|
    t.string "decision_review_evidence_attachment_guid"
    t.string "appeal_submission_id"
    t.string "lighthouse_upload_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "appeal_submissions", force: :cascade do |t|
    t.string "user_uuid"
    t.string "submitted_appeal_uuid"
    t.string "type_of_appeal"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "board_review_option"
    t.text "upload_metadata_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
  end

  create_table "appeals_api_event_subscriptions", force: :cascade do |t|
    t.string "topic"
    t.string "callback"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["topic", "callback"], name: "index_appeals_api_event_subscriptions_on_topic_and_callback"
  end

  create_table "appeals_api_evidence_submissions", force: :cascade do |t|
    t.string "supportable_type"
    t.string "supportable_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "source"
    t.uuid "guid", null: false
    t.integer "upload_submission_id", null: false
    t.text "file_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["guid"], name: "index_appeals_api_evidence_submissions_on_guid"
    t.index ["supportable_type", "supportable_id"], name: "evidence_submission_supportable_id_type_index"
    t.index ["upload_submission_id"], name: "index_appeals_api_evidence_submissions_on_upload_submission_id", unique: true
  end

  create_table "appeals_api_higher_level_reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.string "detail"
    t.string "source"
    t.string "pdf_version"
    t.string "api_version"
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
  end

  create_table "appeals_api_notice_of_disagreements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "status", default: "pending", null: false
    t.string "code"
    t.string "detail"
    t.string "source"
    t.string "board_review_option"
    t.string "pdf_version"
    t.string "api_version"
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
  end

  create_table "appeals_api_status_updates", force: :cascade do |t|
    t.string "from"
    t.string "to"
    t.string "statusable_type"
    t.string "statusable_id"
    t.datetime "status_update_time"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["statusable_type", "statusable_id"], name: "status_update_id_type_index"
  end

  create_table "appeals_api_supplemental_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "pending"
    t.string "code"
    t.string "detail"
    t.string "source"
    t.string "pdf_version"
    t.string "api_version"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "encrypted_kms_key"
    t.boolean "evidence_submission_indicated"
    t.date "verified_decryptable_at"
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
    t.text "metadata_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["created_at"], name: "index_async_transactions_on_created_at"
    t.index ["id", "type"], name: "index_async_transactions_on_id_and_type"
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
    t.index ["lat"], name: "index_base_facilities_on_lat"
    t.index ["location"], name: "index_base_facilities_on_location", using: :gist
    t.index ["name"], name: "index_base_facilities_on_name", opclass: :gin_trgm_ops, using: :gin
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

  create_table "claims_api_auto_established_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.integer "evss_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "md5"
    t.string "source"
    t.string "flashes", default: [], array: true
    t.jsonb "special_issues", default: []
    t.string "veteran_icn"
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "file_data_ciphertext"
    t.text "evss_response_ciphertext"
    t.text "bgs_flash_responses_ciphertext"
    t.text "bgs_special_issue_responses_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["evss_id"], name: "index_claims_api_auto_established_claims_on_evss_id"
    t.index ["md5"], name: "index_claims_api_auto_established_claims_on_md5"
    t.index ["source"], name: "index_claims_api_auto_established_claims_on_source"
  end

  create_table "claims_api_power_of_attorneys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.string "current_poa"
    t.string "md5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vbms_new_document_version_ref_id"
    t.string "vbms_document_series_ref_id"
    t.string "vbms_error_message"
    t.integer "vbms_upload_failure_count", default: 0
    t.string "header_md5"
    t.string "signature_errors", default: [], array: true
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "file_data_ciphertext"
    t.text "source_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["header_md5"], name: "index_claims_api_power_of_attorneys_on_header_md5"
  end

  create_table "claims_api_supporting_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "auto_established_claim_id"
    t.text "file_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
  end

  create_table "covid_vaccine_expanded_registration_submissions", id: :serial, force: :cascade do |t|
    t.string "submission_uuid", null: false
    t.string "vetext_sid"
    t.boolean "sequestered", default: true, null: false
    t.string "state"
    t.string "email_confirmation_id"
    t.string "enrollment_id"
    t.string "batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "raw_form_data_ciphertext"
    t.text "eligibility_info_ciphertext"
    t.text "form_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["batch_id"], name: "index_covid_vaccine_expanded_reg_submissions_on_batch_id"
    t.index ["state"], name: "index_covid_vaccine_expanded_registration_submissions_on_state"
    t.index ["submission_uuid"], name: "index_covid_vaccine_expanded_on_submission_id", unique: true
    t.index ["vetext_sid"], name: "index_covid_vaccine_expanded_on_vetext_sid", unique: true
  end

  create_table "covid_vaccine_registration_submissions", id: :serial, force: :cascade do |t|
    t.string "sid"
    t.uuid "account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "expanded", default: false, null: false
    t.boolean "sequestered", default: false, null: false
    t.string "email_confirmation_id"
    t.string "enrollment_id"
    t.text "form_data_ciphertext"
    t.text "raw_form_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["account_id", "created_at"], name: "index_covid_vaccine_registry_submissions_2"
    t.index ["sid"], name: "index_covid_vaccine_registry_submissions_on_sid", unique: true
  end

  create_table "deprecated_user_accounts", force: :cascade do |t|
    t.uuid "user_account_id"
    t.bigint "user_verification_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_account_id"], name: "index_deprecated_user_accounts_on_user_account_id", unique: true
    t.index ["user_verification_id"], name: "index_deprecated_user_accounts_on_user_verification_id", unique: true
  end

  create_table "directory_applications", force: :cascade do |t|
    t.string "name"
    t.string "logo_url"
    t.string "app_type"
    t.text "service_categories", default: [], array: true
    t.text "platforms", default: [], array: true
    t.string "app_url"
    t.text "description"
    t.string "privacy_url"
    t.string "tos_url"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_directory_applications_on_name", unique: true
  end

  create_table "disability_contentions", id: :serial, force: :cascade do |t|
    t.integer "code", null: false
    t.string "medical_term", null: false
    t.string "lay_term"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_disability_contentions_on_code", unique: true
    t.index ["lay_term"], name: "index_disability_contentions_on_lay_term", opclass: :gin_trgm_ops, using: :gin
    t.index ["medical_term"], name: "index_disability_contentions_on_medical_term", opclass: :gin_trgm_ops, using: :gin
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
    t.datetime "vssc_extract_date", default: "2001-01-01 00:00:00"
    t.index ["polygon"], name: "index_drivetime_bands_on_polygon", using: :gist
  end

  create_table "education_benefits_claims", id: :serial, force: :cascade do |t|
    t.datetime "submitted_at"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "regional_processing_office", null: false
    t.string "form_type", default: "1990"
    t.integer "saved_claim_id", null: false
    t.text "form_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
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
    t.boolean "vrrap", default: false, null: false
    t.index ["created_at"], name: "index_education_benefits_submissions_on_created_at"
    t.index ["education_benefits_claim_id"], name: "index_education_benefits_claim_id", unique: true
    t.index ["region", "created_at", "form_type"], name: "index_edu_benefits_subs_ytd"
  end

  create_table "education_stem_automated_decisions", force: :cascade do |t|
    t.bigint "education_benefits_claim_id"
    t.string "automated_decision_state", default: "init"
    t.string "user_uuid", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "poa"
    t.integer "remaining_entitlement"
    t.datetime "denial_email_sent_at"
    t.datetime "confirmation_email_sent_at"
    t.text "auth_headers_json_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["education_benefits_claim_id"], name: "index_education_stem_automated_decisions_on_claim_id"
    t.index ["user_uuid"], name: "index_education_stem_automated_decisions_on_user_uuid"
  end

  create_table "evss_claims", id: :serial, force: :cascade do |t|
    t.integer "evss_id", null: false
    t.json "data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_uuid", null: false
    t.json "list_data", default: {}, null: false
    t.boolean "requested_decision", default: false, null: false
    t.index ["evss_id"], name: "index_evss_claims_on_evss_id"
    t.index ["updated_at"], name: "index_evss_claims_on_updated_at"
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

  create_table "form1010cg_submissions", force: :cascade do |t|
    t.string "carma_case_id", limit: 18, null: false
    t.datetime "accepted_at", null: false
    t.json "metadata"
    t.json "attachments"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "claim_guid", null: false
    t.index ["carma_case_id"], name: "index_form1010cg_submissions_on_carma_case_id", unique: true
    t.index ["claim_guid"], name: "index_form1010cg_submissions_on_claim_guid", unique: true
  end

  create_table "form526_job_statuses", id: :serial, force: :cascade do |t|
    t.integer "form526_submission_id", null: false
    t.string "job_id", null: false
    t.string "job_class", null: false
    t.string "status", null: false
    t.string "error_class"
    t.string "error_message"
    t.datetime "updated_at", null: false
    t.jsonb "bgjob_errors", default: {}
    t.index ["bgjob_errors"], name: "index_form526_job_statuses_on_bgjob_errors", using: :gin
    t.index ["form526_submission_id"], name: "index_form526_job_statuses_on_form526_submission_id"
    t.index ["job_id"], name: "index_form526_job_statuses_on_job_id", unique: true
  end

  create_table "form526_submissions", id: :serial, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.integer "saved_claim_id", null: false
    t.integer "submitted_claim_id"
    t.boolean "workflow_complete", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "multiple_birls", comment: "*After* a SubmitForm526 Job fails, a lookup is done to see if the veteran has multiple BIRLS IDs. This field gets set to true if that is the case. If the initial submit job succeeds, this field will remain false whether or not the veteran has multiple BIRLS IDs --so this field cannot technically be used to sum all Form526 veterans that have multiple BIRLS. This field /can/ give us an idea of how often having multiple BIRLS IDs is a problem."
    t.text "auth_headers_json_ciphertext"
    t.text "form_json_ciphertext"
    t.text "birls_ids_tried_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["saved_claim_id"], name: "index_form526_submissions_on_saved_claim_id", unique: true
    t.index ["submitted_claim_id"], name: "index_form526_submissions_on_submitted_claim_id", unique: true
    t.index ["user_uuid"], name: "index_form526_submissions_on_user_uuid"
  end

  create_table "form_attachments", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "guid", null: false
    t.string "type", null: false
    t.text "file_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["guid", "type"], name: "index_form_attachments_on_guid_and_type", unique: true
    t.index ["id", "type"], name: "index_form_attachments_on_id_and_type"
  end

  create_table "gibs_not_found_users", id: :serial, force: :cascade do |t|
    t.string "edipi", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "dob", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "ssn_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["edipi"], name: "index_gibs_not_found_users_on_edipi"
  end

  create_table "health_care_applications", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "pending", null: false
    t.string "form_submission_id_string"
    t.string "timestamp"
  end

  create_table "health_quest_questionnaire_responses", force: :cascade do |t|
    t.string "user_uuid"
    t.string "appointment_id"
    t.string "questionnaire_response_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "questionnaire_response_data_ciphertext"
    t.text "user_demographics_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["user_uuid", "questionnaire_response_id"], name: "find_by_user_qr", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "metadata"
    t.datetime "expires_at"
    t.text "form_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["form_id", "user_uuid"], name: "index_in_progress_forms_on_form_id_and_user_uuid", unique: true
    t.index ["user_uuid"], name: "index_in_progress_forms_on_user_uuid"
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
    t.index ["mhv_correlation_id"], name: "index_mhv_accounts_on_mhv_correlation_id"
    t.index ["user_uuid", "mhv_correlation_id"], name: "index_mhv_accounts_on_user_uuid_and_mhv_correlation_id", unique: true
  end

  create_table "mobile_users", force: :cascade do |t|
    t.string "icn", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["icn"], name: "index_mobile_users_on_icn", unique: true
  end

  create_table "mobile_vaccines", force: :cascade do |t|
    t.integer "cvx_code", null: false
    t.string "group_name", null: false
    t.string "manufacturer"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cvx_code"], name: "index_mobile_vaccines_on_cvx_code", unique: true
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
    t.text "file_data_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["guid"], name: "index_persistent_attachments_on_guid", unique: true
    t.index ["id", "type"], name: "index_persistent_attachments_on_id_and_type"
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

  create_table "pghero_query_stats", force: :cascade do |t|
    t.text "database"
    t.text "user"
    t.text "query"
    t.bigint "query_hash"
    t.float "total_time"
    t.bigint "calls"
    t.datetime "captured_at"
    t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
  end

  create_table "preferred_facilities", force: :cascade do |t|
    t.string "facility_code", null: false
    t.integer "account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["facility_code", "account_id"], name: "index_preferred_facilities_on_facility_code_and_account_id", unique: true
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
    t.string "form_id"
    t.uuid "guid", null: false
    t.string "type"
    t.text "form_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["created_at", "type"], name: "index_saved_claims_on_created_at_and_type"
    t.index ["guid"], name: "index_saved_claims_on_guid", unique: true
    t.index ["id", "type"], name: "index_saved_claims_on_id_and_type"
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

  create_table "spool_file_events", force: :cascade do |t|
    t.integer "rpo"
    t.integer "number_of_submissions"
    t.string "filename"
    t.datetime "successful_at"
    t.integer "retry_attempt", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rpo", "filename"], name: "index_spool_file_events_uniqueness", unique: true
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

  create_table "test_user_dashboard_tud_account_availability_logs", force: :cascade do |t|
    t.string "account_uuid"
    t.datetime "checkout_time"
    t.datetime "checkin_time"
    t.boolean "has_checkin_error"
    t.boolean "is_manual_checkin"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_uuid"], name: "tud_account_availability_logs"
  end

  create_table "test_user_dashboard_tud_account_checkouts", force: :cascade do |t|
    t.string "account_uuid"
    t.datetime "checkout_time"
    t.datetime "checkin_time"
    t.boolean "has_checkin_error"
    t.boolean "is_manual_checkin"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "test_user_dashboard_tud_accounts", force: :cascade do |t|
    t.string "account_uuid"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.string "gender"
    t.datetime "birth_date"
    t.integer "ssn"
    t.string "phone"
    t.string "email"
    t.string "password"
    t.datetime "checkout_time"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "services"
    t.string "id_type"
    t.string "loa"
    t.string "account_type"
    t.uuid "idme_uuid"
    t.text "notes"
  end

  create_table "user_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "icn"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["icn"], name: "index_user_accounts_on_icn", unique: true
  end

  create_table "user_verifications", force: :cascade do |t|
    t.uuid "user_account_id"
    t.string "idme_uuid"
    t.string "logingov_uuid"
    t.string "mhv_uuid"
    t.string "dslogon_uuid"
    t.datetime "verified_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["dslogon_uuid"], name: "index_user_verifications_on_dslogon_uuid", unique: true
    t.index ["idme_uuid"], name: "index_user_verifications_on_idme_uuid", unique: true
    t.index ["logingov_uuid"], name: "index_user_verifications_on_logingov_uuid", unique: true
    t.index ["mhv_uuid"], name: "index_user_verifications_on_mhv_uuid", unique: true
    t.index ["user_account_id"], name: "index_user_verifications_on_user_account_id"
    t.index ["verified_at"], name: "index_user_verifications_on_verified_at"
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
    t.boolean "valid_pdf", default: false
    t.text "form_usage"
    t.text "form_tool_intro"
    t.string "form_tool_url"
    t.string "form_type"
    t.string "language"
    t.datetime "deleted_at"
    t.string "related_forms", array: true
    t.jsonb "benefit_categories"
    t.string "form_details_url"
    t.jsonb "va_form_administration"
    t.integer "row_id"
    t.float "ranking"
    t.string "tags"
    t.index ["valid_pdf"], name: "index_va_forms_forms_on_valid_pdf"
  end

  create_table "vba_documents_git_items", force: :cascade do |t|
    t.string "url", null: false
    t.jsonb "git_item"
    t.boolean "notified", default: false
    t.string "label"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["notified", "label"], name: "index_vba_documents_git_items_on_notified_and_label"
    t.index ["url"], name: "index_vba_documents_git_items_on_url", unique: true
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
    t.json "uploaded_pdf"
    t.boolean "use_active_storage", default: false
    t.jsonb "metadata", default: {}
    t.index ["created_at"], name: "index_vba_documents_upload_submissions_on_created_at"
    t.index ["guid"], name: "index_vba_documents_upload_submissions_on_guid"
    t.index ["s3_deleted"], name: "index_vba_documents_upload_submissions_on_s3_deleted"
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
    t.string "poa_codes", default: [], array: true
    t.string "user_types", default: [], array: true
    t.text "ssn_ciphertext"
    t.text "dob_ciphertext"
    t.text "encrypted_kms_key"
    t.date "verified_decryptable_at"
    t.index ["representative_id", "first_name", "last_name"], name: "index_vso_grp", unique: true
    t.check_constraint "representative_id IS NOT NULL", name: "veteran_representatives_representative_id_null"
  end

  create_table "vic_submissions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "pending", null: false
    t.uuid "guid", null: false
    t.json "response"
    t.index ["guid"], name: "index_vic_submissions_on_guid", unique: true
  end

  create_table "webhooks_notification_attempt_assocs", id: false, force: :cascade do |t|
    t.bigint "webhooks_notification_id", null: false
    t.bigint "webhooks_notification_attempt_id", null: false
    t.index ["webhooks_notification_attempt_id"], name: "index_wh_assoc_attempt_id"
    t.index ["webhooks_notification_id"], name: "index_wh_assoc_notification_id"
  end

  create_table "webhooks_notification_attempts", force: :cascade do |t|
    t.boolean "success", default: false
    t.jsonb "response", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "webhooks_notifications", force: :cascade do |t|
    t.string "api_name", null: false
    t.string "consumer_name", null: false
    t.uuid "consumer_id", null: false
    t.uuid "api_guid", null: false
    t.string "event", null: false
    t.string "callback_url", null: false
    t.jsonb "msg", null: false
    t.integer "final_attempt_id"
    t.integer "processing"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["api_name", "consumer_id", "api_guid", "event", "final_attempt_id"], name: "index_wh_notify"
    t.index ["final_attempt_id", "api_name", "event", "api_guid"], name: "index_wk_notify_processing"
  end

  create_table "webhooks_subscriptions", force: :cascade do |t|
    t.string "api_name", null: false
    t.string "consumer_name", null: false
    t.uuid "consumer_id", null: false
    t.uuid "api_guid"
    t.jsonb "events", default: {"subscriptions"=>[]}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["api_name", "consumer_id", "api_guid"], name: "index_webhooks_subscription", unique: true
  end

  add_foreign_key "account_login_stats", "accounts"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "deprecated_user_accounts", "user_accounts"
  add_foreign_key "deprecated_user_accounts", "user_verifications"
  add_foreign_key "user_verifications", "user_accounts"
end
