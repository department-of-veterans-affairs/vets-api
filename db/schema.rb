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

ActiveRecord::Schema[7.2].define(version: 2025_01_17_180318) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "fuzzystrmatch"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "uuid-ossp"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "itf_remediation_status", ["unprocessed"]

  create_table "account_login_stats", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "idme_at"
    t.datetime "myhealthevet_at"
    t.datetime "dslogon_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "accreditations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "accredited_individual_id", null: false
    t.uuid "accredited_organization_id", null: false
    t.boolean "can_accept_reject_poa"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accredited_individual_id", "accredited_organization_id"], name: "index_accreditations_on_indi_and_org_ids", unique: true
    t.index ["accredited_organization_id"], name: "index_accreditations_on_accredited_organization_id"
  end

  create_table "accredited_individuals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ogc_id", null: false
    t.string "registration_number", null: false
    t.string "poa_code", limit: 3
    t.string "individual_type", null: false
    t.string "first_name"
    t.string "middle_initial"
    t.string "last_name"
    t.string "full_name"
    t.string "email"
    t.string "phone"
    t.string "address_type"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_line3"
    t.string "city"
    t.string "country_code_iso3"
    t.string "country_name"
    t.string "county_name"
    t.string "county_code"
    t.string "international_postal_code"
    t.string "province"
    t.string "state_code"
    t.string "zip_code"
    t.string "zip_suffix"
    t.jsonb "raw_address"
    t.float "lat"
    t.float "long"
    t.geography "location", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_accredited_individuals_on_full_name"
    t.index ["location"], name: "index_accredited_individuals_on_location", using: :gist
    t.index ["poa_code"], name: "index_accredited_individuals_on_poa_code"
    t.index ["registration_number", "individual_type"], name: "index_on_reg_num_and_type_for_accredited_individuals", unique: true
  end

  create_table "accredited_organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ogc_id", null: false
    t.string "poa_code", limit: 3, null: false
    t.string "name"
    t.string "phone"
    t.string "address_type"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_line3"
    t.string "city"
    t.string "country_code_iso3"
    t.string "country_name"
    t.string "county_name"
    t.string "county_code"
    t.string "international_postal_code"
    t.string "province"
    t.string "state_code"
    t.string "zip_code"
    t.string "zip_suffix"
    t.jsonb "raw_address"
    t.float "lat"
    t.float "long"
    t.geography "location", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location"], name: "index_accredited_organizations_on_location", using: :gist
    t.index ["name"], name: "index_accredited_organizations_on_name"
    t.index ["poa_code"], name: "index_accredited_organizations_on_poa_code", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "failure_notification_sent_at"
    t.index ["appeal_submission_id"], name: "index_appeal_submission_uploads_on_appeal_submission_id"
  end

  create_table "appeal_submissions", force: :cascade do |t|
    t.string "user_uuid"
    t.string "submitted_appeal_uuid"
    t.string "type_of_appeal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "board_review_option"
    t.text "upload_metadata_ciphertext"
    t.text "encrypted_kms_key"
    t.uuid "user_account_id"
    t.datetime "failure_notification_sent_at"
    t.index ["submitted_appeal_uuid"], name: "index_appeal_submissions_on_submitted_appeal_uuid"
    t.index ["user_account_id"], name: "index_appeal_submissions_on_user_account_id"
  end

  create_table "appeals_api_evidence_submissions", force: :cascade do |t|
    t.string "supportable_type"
    t.string "supportable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.uuid "guid", null: false
    t.integer "upload_submission_id", null: false
    t.text "file_data_ciphertext"
    t.text "encrypted_kms_key"
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
    t.string "veteran_icn"
    t.jsonb "metadata", default: {}
    t.index ["veteran_icn"], name: "index_appeals_api_higher_level_reviews_on_veteran_icn"
  end

  create_table "appeals_api_notice_of_disagreements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "form_data_ciphertext"
    t.text "auth_headers_ciphertext"
    t.text "encrypted_kms_key"
    t.boolean "evidence_submission_indicated"
    t.string "veteran_icn"
    t.jsonb "metadata", default: {}
    t.index ["veteran_icn"], name: "index_appeals_api_supplemental_claims_on_veteran_icn"
  end

  create_table "ar_power_of_attorney_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "power_of_attorney_request_id", null: false
    t.text "encrypted_kms_key"
    t.text "data_ciphertext", null: false
    t.string "claimant_city_ciphertext", null: false
    t.string "claimant_city_bidx", null: false
    t.string "claimant_state_code_ciphertext", null: false
    t.string "claimant_state_code_bidx", null: false
    t.string "claimant_zip_code_ciphertext", null: false
    t.string "claimant_zip_code_bidx", null: false
    t.index ["claimant_city_bidx", "claimant_state_code_bidx", "claimant_zip_code_bidx"], name: "idx_on_claimant_city_bidx_claimant_state_code_bidx__11e9adbe25"
    t.index ["power_of_attorney_request_id"], name: "idx_on_power_of_attorney_request_id_fc59a0dabc", unique: true
  end

  create_table "ar_power_of_attorney_request_decisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "type", null: false
    t.uuid "creator_id", null: false
    t.index ["creator_id"], name: "index_ar_power_of_attorney_request_decisions_on_creator_id"
  end

  create_table "ar_power_of_attorney_request_expirations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
  end

  create_table "ar_power_of_attorney_request_resolutions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "power_of_attorney_request_id", null: false
    t.string "resolving_type", null: false
    t.uuid "resolving_id", null: false
    t.text "reason_ciphertext"
    t.text "encrypted_kms_key"
    t.datetime "created_at", null: false
    t.index ["power_of_attorney_request_id"], name: "idx_on_power_of_attorney_request_id_fd7d2d11b1", unique: true
    t.index ["resolving_type", "resolving_id"], name: "unique_resolving_type_and_id", unique: true
  end

  create_table "ar_power_of_attorney_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "claimant_id", null: false
    t.datetime "created_at", null: false
    t.string "claimant_type", null: false
    t.string "power_of_attorney_holder_type", null: false
    t.uuid "power_of_attorney_holder_id", null: false
    t.uuid "accredited_individual_id", null: false
    t.index ["accredited_individual_id"], name: "idx_on_accredited_individual_id_a0a1fab1e0"
    t.index ["claimant_id"], name: "index_ar_power_of_attorney_requests_on_claimant_id"
    t.index ["power_of_attorney_holder_type", "power_of_attorney_holder_id"], name: "index_ar_power_of_attorney_requests_on_power_of_attorney_holder"
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
    t.uuid "user_account_id"
    t.index ["created_at"], name: "index_async_transactions_on_created_at"
    t.index ["id", "type"], name: "index_async_transactions_on_id_and_type"
    t.index ["source_id"], name: "index_async_transactions_on_source_id"
    t.index ["transaction_id", "source"], name: "index_async_transactions_on_transaction_id_and_source", unique: true
    t.index ["user_account_id"], name: "index_async_transactions_on_user_account_id"
    t.index ["user_uuid"], name: "index_async_transactions_on_user_uuid"
  end

