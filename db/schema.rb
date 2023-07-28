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

ActiveRecord::Schema.define(version: 2023_07_25_172333) do

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
    t.uuid "user_account_id"
    t.index ["user_account_id"], name: "index_appeal_submissions_on_user_account_id"
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
    t.string "veteran_icn"
    t.jsonb "metadata", default: {}
    t.index ["veteran_icn"], name: "index_appeals_api_higher_level_reviews_on_veteran_icn"
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
    t.string "veteran_icn"
    t.jsonb "metadata", default: {}
    t.index ["veteran_icn"], name: "index_appeals_api_notice_of_disagreements_on_veteran_icn"
  end

  create_table "appeals_api_status_updates", force: :cascade do |t|
    t.string "from"
    t.string "to"
    t.string "statusable_type"
    t.string "statusable_id"
    t.datetime "status_update_time"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "code"
    t.string "detail"
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
    t.string "veteran_icn"
    t.jsonb "metadata", default: {}
    t.index ["veteran_icn"], name: "index_appeals_api_supplemental_claims_on_veteran_icn"
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
    t.uuid "user_account_id"
    t.index ["created_at"], name: "index_async_transactions_on_created_at"
    t.index ["id", "type"], name: "index_async_transactions_on_id_and_type"
    t.index ["source_id"], name: "index_async_transactions_on_source_id"
    t.index ["transaction_id", "source"], name: "index_async_transactions_on_transaction_id_and_source", unique: true
    t.index ["transaction_id"], name: "index_async_transactions_on_transaction_id"
    t.index ["user_account_id"], name: "index_async_transactions_on_user_account_id"
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
    t.string "cid"
    t.index ["evss_id"], name: "index_claims_api_auto_established_claims_on_evss_id"
    t.index ["md5"], name: "index_claims_api_auto_established_claims_on_md5"
    t.index ["source"], name: "index_claims_api_auto_established_claims_on_source"
  end

  create_table "claims_api_claim_submissions", force: :cascade do |t|
    t.uuid "claim_id", null: false
    t.string "claim_type", null: false
    t.string "consumer_label", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["claim_id"], name: "index_claims_api_claim_submissions_on_claim_id"
  end

  create_table "claims_api_evidence_waiver_submissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "auth_headers_ciphertext"
    t.text "encrypted_kms_key"
    t.string "cid"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "status"
    t.string "vbms_error_message"
    t.string "bgs_error_message"
    t.integer "vbms_upload_failure_count", default: 0
    t.integer "bgs_upload_failure_count", default: 0
    t.string "claim_id"
  end

  create_table "claims_api_intent_to_files", force: :cascade do |t|
    t.string "status"
    t.string "cid"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
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
    t.string "cid"
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

  create_table "client_configs", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "authentication", null: false
    t.boolean "anti_csrf", null: false
    t.text "redirect_uri", null: false
    t.interval "access_token_duration", null: false
    t.string "access_token_audience", null: false
    t.interval "refresh_token_duration", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "logout_redirect_uri"
    t.boolean "pkce"
    t.string "certificates", array: true
    t.string "refresh_token_path"
    t.index ["client_id"], name: "index_client_configs_on_client_id", unique: true
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

  create_table "credential_adoption_email_records", force: :cascade do |t|
    t.string "icn", null: false
    t.string "email_address", null: false
    t.string "email_template_id", null: false
    t.datetime "email_triggered_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email_address"], name: "index_credential_adoption_email_records_on_email_address"
    t.index ["email_template_id"], name: "index_credential_adoption_email_records_on_email_template_id"
    t.index ["icn"], name: "index_credential_adoption_email_records_on_icn"
  end

  create_table "deprecated_user_accounts", force: :cascade do |t|
    t.uuid "user_account_id"
    t.bigint "user_verification_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_account_id"], name: "index_deprecated_user_accounts_on_user_account_id", unique: true
    t.index ["user_verification_id"], name: "index_deprecated_user_accounts_on_user_verification_id", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.string "key"
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["key"], name: "index_devices_on_key", unique: true
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
    t.uuid "user_account_id"
    t.index ["education_benefits_claim_id"], name: "index_education_stem_automated_decisions_on_claim_id"
    t.index ["user_account_id"], name: "index_education_stem_automated_decisions_on_user_account_id"
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
    t.uuid "user_account_id"
    t.index ["evss_id"], name: "index_evss_claims_on_evss_id"
    t.index ["updated_at"], name: "index_evss_claims_on_updated_at"
    t.index ["user_account_id"], name: "index_evss_claims_on_user_account_id"
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

  create_table "form1095_bs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "veteran_icn", null: false
    t.integer "tax_year", null: false
    t.jsonb "form_data_ciphertext", null: false
    t.text "encrypted_kms_key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["veteran_icn", "tax_year"], name: "index_form1095_bs_on_veteran_icn_and_tax_year", unique: true
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
    t.uuid "user_account_id"
    t.string "backup_submitted_claim_id", comment: "*After* a SubmitForm526 Job has exhausted all attempts, a paper submission is generated and sent to Central Mail Portal.This column will be nil for all submissions where a backup submission is not generated.It will have the central mail id for submissions where a backup submission is submitted."
    t.index ["saved_claim_id"], name: "index_form526_submissions_on_saved_claim_id", unique: true
    t.index ["submitted_claim_id"], name: "index_form526_submissions_on_submitted_claim_id", unique: true
    t.index ["user_account_id"], name: "index_form526_submissions_on_user_account_id"
    t.index ["user_uuid"], name: "index_form526_submissions_on_user_uuid"
  end

  create_table "form5655_submissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "user_uuid", null: false
    t.text "form_json_ciphertext", null: false
    t.text "metadata_ciphertext"
    t.text "encrypted_kms_key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.uuid "user_account_id"
    t.index ["user_account_id"], name: "index_form5655_submissions_on_user_account_id"
    t.index ["user_uuid"], name: "index_form5655_submissions_on_user_uuid"
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

  create_table "gmt_thresholds", force: :cascade do |t|
    t.integer "effective_year", null: false
    t.string "state_name", null: false
    t.string "county_name", null: false
    t.integer "fips", null: false
    t.integer "trhd1", null: false
    t.integer "trhd2", null: false
    t.integer "trhd3", null: false
    t.integer "trhd4", null: false
    t.integer "trhd5", null: false
    t.integer "trhd6", null: false
    t.integer "trhd7", null: false
    t.integer "trhd8", null: false
    t.integer "msa", null: false
    t.string "msa_name"
    t.integer "version", null: false
    t.datetime "created", null: false
    t.datetime "updated"
    t.string "created_by"
    t.string "updated_by"
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
    t.uuid "user_account_id"
    t.index ["user_account_id"], name: "index_health_quest_questionnaire_responses_on_user_account_id"
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
    t.uuid "user_account_id"
    t.index ["form_id", "user_uuid"], name: "index_in_progress_forms_on_form_id_and_user_uuid", unique: true
    t.index ["user_account_id"], name: "index_in_progress_forms_on_user_account_id"
    t.index ["user_uuid"], name: "index_in_progress_forms_on_user_uuid"
  end

  create_table "inherited_proof_verified_user_accounts", force: :cascade do |t|
    t.uuid "user_account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_account_id"], name: "index_inherited_proof_verified_user_accounts_on_user_account_id", unique: true
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

  create_table "mhv_opt_in_flags", force: :cascade do |t|
    t.uuid "user_account_id"
    t.string "feature", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["feature"], name: "index_mhv_opt_in_flags_on_feature"
    t.index ["user_account_id"], name: "index_mhv_opt_in_flags_on_user_account_id"
  end

  create_table "mobile_users", force: :cascade do |t|
    t.string "icn", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "vet360_link_attempts"
    t.boolean "vet360_linked"
    t.index ["icn"], name: "index_mobile_users_on_icn", unique: true
  end

  create_table "oauth_sessions", force: :cascade do |t|
    t.uuid "handle", null: false
    t.uuid "user_account_id", null: false
    t.string "hashed_refresh_token", null: false
    t.datetime "refresh_expiration", null: false
    t.datetime "refresh_creation", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_verification_id", null: false
    t.string "credential_email"
    t.string "client_id", null: false
    t.index ["handle"], name: "index_oauth_sessions_on_handle", unique: true
    t.index ["hashed_refresh_token"], name: "index_oauth_sessions_on_hashed_refresh_token", unique: true
    t.index ["refresh_creation"], name: "index_oauth_sessions_on_refresh_creation"
    t.index ["refresh_expiration"], name: "index_oauth_sessions_on_refresh_expiration"
    t.index ["user_account_id"], name: "index_oauth_sessions_on_user_account_id"
    t.index ["user_verification_id"], name: "index_oauth_sessions_on_user_verification_id"
  end

  create_table "onsite_notifications", force: :cascade do |t|
    t.string "template_id", null: false
    t.string "va_profile_id", null: false
    t.boolean "dismissed", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["va_profile_id", "dismissed"], name: "show_onsite_notifications_index"
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

  create_table "pghero_space_stats", force: :cascade do |t|
    t.text "database"
    t.text "schema"
    t.text "relation"
    t.bigint "size"
    t.datetime "captured_at"
    t.index ["database", "captured_at"], name: "index_pghero_space_stats_on_database_and_captured_at"
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

  create_table "service_account_configs", force: :cascade do |t|
    t.string "service_account_id", null: false
    t.text "description", null: false
    t.text "scopes", null: false, array: true
    t.string "access_token_audience", null: false
    t.interval "access_token_duration", null: false
    t.string "certificates", array: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["service_account_id"], name: "index_service_account_configs_on_service_account_id", unique: true
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

  create_table "std_counties", force: :cascade do |t|
    t.string "name", null: false
    t.integer "county_number", null: false
    t.string "description", null: false
    t.integer "state_id", null: false
    t.integer "version", null: false
    t.datetime "created", null: false
    t.datetime "updated"
    t.string "created_by"
    t.string "updated_by"
  end

  create_table "std_incomethresholds", force: :cascade do |t|
    t.integer "income_threshold_year", null: false
    t.integer "exempt_amount", null: false
    t.integer "medical_expense_deductible", null: false
    t.integer "child_income_exclusion", null: false
    t.integer "dependent", null: false
    t.integer "add_dependent_threshold", null: false
    t.integer "property_threshold", null: false
    t.integer "pension_threshold"
    t.integer "pension_1_dependent"
    t.integer "add_dependent_pension"
    t.integer "ninety_day_hospital_copay"
    t.integer "add_ninety_day_hospital_copay"
    t.integer "outpatient_basic_care_copay"
    t.integer "outpatient_specialty_copay"
    t.datetime "threshold_effective_date"
    t.integer "aid_and_attendance_threshold"
    t.integer "outpatient_preventive_copay"
    t.integer "medication_copay"
    t.integer "medication_copay_annual_cap"
    t.integer "ltc_inpatient_copay"
    t.integer "ltc_outpatient_copay"
    t.integer "ltc_domiciliary_copay"
    t.integer "inpatient_per_diem"
    t.string "description"
    t.integer "version", null: false
    t.datetime "created", null: false
    t.datetime "updated"
    t.string "created_by"
    t.string "updated_by"
  end

  create_table "std_states", force: :cascade do |t|
    t.string "name", null: false
    t.string "postal_name", null: false
    t.integer "fips_code", null: false
    t.integer "country_id", null: false
    t.integer "version", null: false
    t.datetime "created", null: false
    t.datetime "updated"
    t.string "created_by"
    t.string "updated_by"
  end

  create_table "std_zipcodes", force: :cascade do |t|
    t.string "zip_code", null: false
    t.integer "zip_classification_id"
    t.integer "preferred_zip_place_id"
    t.integer "state_id", null: false
    t.integer "county_number", null: false
    t.integer "version", null: false
    t.datetime "created", null: false
    t.datetime "updated"
    t.string "created_by"
    t.string "updated_by"
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
    t.uuid "user_account_id"
    t.index ["user_account_id"], name: "index_terms_and_conditions_acceptances_on_user_account_id"
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
    t.string "loa"
    t.uuid "idme_uuid"
    t.text "notes"
    t.string "mfa_code"
    t.uuid "logingov_uuid"
    t.text "id_types", default: [], array: true
  end

  create_table "user_acceptable_verified_credentials", force: :cascade do |t|
    t.datetime "acceptable_verified_credential_at"
    t.datetime "idme_verified_credential_at"
    t.uuid "user_account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["acceptable_verified_credential_at"], name: "index_user_avc_on_acceptable_verified_credential_at"
    t.index ["idme_verified_credential_at"], name: "index_user_avc_on_idme_verified_credential_at"
    t.index ["user_account_id"], name: "index_user_acceptable_verified_credentials_on_user_account_id", unique: true
  end

  create_table "user_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "icn"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["icn"], name: "index_user_accounts_on_icn", unique: true
  end

  create_table "user_credential_emails", force: :cascade do |t|
    t.bigint "user_verification_id"
    t.text "credential_email_ciphertext"
    t.text "encrypted_kms_key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_verification_id"], name: "index_user_credential_emails_on_user_verification_id", unique: true
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
    t.string "backing_idme_uuid"
    t.index ["backing_idme_uuid"], name: "index_user_verifications_on_backing_idme_uuid"
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

  create_table "va_notify_in_progress_reminders_sent", force: :cascade do |t|
    t.string "form_id", null: false
    t.uuid "user_account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_account_id", "form_id"], name: "index_in_progress_reminders_sent_user_account_form_id", unique: true
    t.index ["user_account_id"], name: "index_va_notify_in_progress_reminders_sent_on_user_account_id"
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

  create_table "vba_documents_monthly_stats", force: :cascade do |t|
    t.integer "month", null: false
    t.integer "year", null: false
    t.jsonb "stats", default: {}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["month", "year"], name: "index_vba_documents_monthly_stats_uniqueness", unique: true
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

  create_table "veteran_device_records", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.boolean "active", default: true, null: false
    t.string "icn", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["device_id"], name: "index_veteran_device_records_on_device_id"
    t.index ["icn", "device_id"], name: "index_veteran_device_records_on_icn_and_device_id", unique: true
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
    t.string "middle_initial"
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
  add_foreign_key "appeal_submissions", "user_accounts"
  add_foreign_key "async_transactions", "user_accounts"
  add_foreign_key "claims_api_claim_submissions", "claims_api_auto_established_claims", column: "claim_id"
  add_foreign_key "deprecated_user_accounts", "user_accounts"
  add_foreign_key "deprecated_user_accounts", "user_verifications"
  add_foreign_key "education_stem_automated_decisions", "user_accounts"
  add_foreign_key "evss_claims", "user_accounts"
  add_foreign_key "form526_submissions", "user_accounts"
  add_foreign_key "form5655_submissions", "user_accounts"
  add_foreign_key "health_quest_questionnaire_responses", "user_accounts"
  add_foreign_key "in_progress_forms", "user_accounts"
  add_foreign_key "inherited_proof_verified_user_accounts", "user_accounts"
  add_foreign_key "mhv_opt_in_flags", "user_accounts"
  add_foreign_key "oauth_sessions", "user_accounts"
  add_foreign_key "oauth_sessions", "user_verifications"
  add_foreign_key "terms_and_conditions_acceptances", "user_accounts"
  add_foreign_key "user_acceptable_verified_credentials", "user_accounts"
  add_foreign_key "user_credential_emails", "user_verifications"
  add_foreign_key "user_verifications", "user_accounts"
  add_foreign_key "va_notify_in_progress_reminders_sent", "user_accounts"
  add_foreign_key "veteran_device_records", "devices"
end
