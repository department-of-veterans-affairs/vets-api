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

ActiveRecord::Schema.define(version: 20190424212410) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "uuid-ossp"
  enable_extension "pg_trgm"
  enable_extension "btree_gin"

  create_table "accounts", force: :cascade do |t|
    t.uuid     "uuid",       null: false
    t.string   "idme_uuid"
    t.string   "icn"
    t.string   "edipi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idme_uuid"], name: "index_accounts_on_idme_uuid", unique: true, using: :btree
    t.index ["uuid"], name: "index_accounts_on_uuid", unique: true, using: :btree
  end

  create_table "async_transactions", force: :cascade do |t|
    t.string   "type"
    t.string   "user_uuid"
    t.string   "source_id"
    t.string   "source"
    t.string   "status"
    t.string   "transaction_id"
    t.string   "transaction_status"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "encrypted_metadata"
    t.string   "encrypted_metadata_iv"
    t.index ["source_id"], name: "index_async_transactions_on_source_id", using: :btree
    t.index ["transaction_id", "source"], name: "index_async_transactions_on_transaction_id_and_source", unique: true, using: :btree
    t.index ["transaction_id"], name: "index_async_transactions_on_transaction_id", using: :btree
    t.index ["user_uuid"], name: "index_async_transactions_on_user_uuid", using: :btree
  end

  create_table "base_facilities", id: false, force: :cascade do |t|
    t.string    "unique_id",                                                                  null: false
    t.string    "name",                                                                       null: false
    t.string    "facility_type",                                                              null: false
    t.string    "classification"
    t.string    "website"
    t.float     "lat",                                                                        null: false
    t.float     "long",                                                                       null: false
    t.jsonb     "address"
    t.jsonb     "phone"
    t.jsonb     "hours"
    t.jsonb     "services"
    t.jsonb     "feedback"
    t.jsonb     "access"
    t.string    "fingerprint"
    t.datetime  "created_at",                                                                 null: false
    t.datetime  "updated_at",                                                                 null: false
    t.geography "location",       limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.index ["location"], name: "index_base_facilities_on_location", using: :gist
    t.index ["name"], name: "index_base_facilities_on_name", using: :gin
    t.index ["unique_id", "facility_type"], name: "index_base_facilities_on_unique_id_and_facility_type", unique: true, using: :btree
  end

  create_table "beta_registrations", force: :cascade do |t|
    t.string   "user_uuid",  null: false
    t.string   "feature",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_uuid", "feature"], name: "index_beta_registrations_on_user_uuid_and_feature", unique: true, using: :btree
  end

  create_table "central_mail_submissions", force: :cascade do |t|
    t.string  "state",          default: "pending", null: false
    t.integer "saved_claim_id",                     null: false
    t.index ["saved_claim_id"], name: "index_central_mail_submissions_on_saved_claim_id", using: :btree
    t.index ["state"], name: "index_central_mail_submissions_on_state", using: :btree
  end

  create_table "claims_api_auto_established_claims", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "status"
    t.string   "encrypted_form_data"
    t.string   "encrypted_form_data_iv"
    t.string   "encrypted_auth_headers"
    t.string   "encrypted_auth_headers_iv"
    t.integer  "evss_id"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "md5"
  end

  create_table "claims_api_supporting_documents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "encrypted_file_data",       null: false
    t.string   "encrypted_file_data_iv",    null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.uuid     "auto_established_claim_id", null: false
  end

  create_table "disability_compensation_job_statuses", force: :cascade do |t|
    t.integer  "disability_compensation_submission_id", null: false
    t.string   "job_id",                                null: false
    t.string   "job_class",                             null: false
    t.string   "status",                                null: false
    t.string   "error_message"
    t.datetime "updated_at",                            null: false
    t.index ["disability_compensation_submission_id"], name: "index_disability_compensation_job_statuses_on_dsc_id", using: :btree
    t.index ["job_id"], name: "index_disability_compensation_job_statuses_on_job_id", unique: true, using: :btree
  end

  create_table "disability_compensation_submissions", force: :cascade do |t|
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.integer  "disability_compensation_id"
    t.integer  "va526ez_submit_transaction_id"
    t.boolean  "complete",                      default: false
  end

  create_table "disability_contentions", force: :cascade do |t|
    t.integer  "code",         null: false
    t.string   "medical_term", null: false
    t.string   "lay_term"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.index ["code"], name: "index_disability_contentions_on_code", unique: true, using: :btree
    t.index ["lay_term"], name: "index_disability_contentions_on_lay_term", using: :gin
    t.index ["medical_term"], name: "index_disability_contentions_on_medical_term", using: :gin
  end

  create_table "education_benefits_claims", force: :cascade do |t|
    t.datetime "submitted_at"
    t.datetime "processed_at"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "encrypted_form"
    t.string   "encrypted_form_iv"
    t.string   "regional_processing_office",                  null: false
    t.string   "form_type",                  default: "1990"
    t.integer  "saved_claim_id",                              null: false
    t.index ["created_at"], name: "index_education_benefits_claims_on_created_at", using: :btree
    t.index ["saved_claim_id"], name: "index_education_benefits_claims_on_saved_claim_id", using: :btree
    t.index ["submitted_at"], name: "index_education_benefits_claims_on_submitted_at", using: :btree
  end

  create_table "education_benefits_submissions", force: :cascade do |t|
    t.string   "region",                                            null: false
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.boolean  "chapter33",                   default: false,       null: false
    t.boolean  "chapter30",                   default: false,       null: false
    t.boolean  "chapter1606",                 default: false,       null: false
    t.boolean  "chapter32",                   default: false,       null: false
    t.string   "status",                      default: "submitted", null: false
    t.integer  "education_benefits_claim_id"
    t.string   "form_type",                   default: "1990",      null: false
    t.boolean  "chapter35",                   default: false,       null: false
    t.boolean  "transfer_of_entitlement",     default: false,       null: false
    t.boolean  "chapter1607",                 default: false,       null: false
    t.boolean  "vettec",                      default: false
    t.index ["education_benefits_claim_id"], name: "index_education_benefits_claim_id", unique: true, using: :btree
    t.index ["region", "created_at", "form_type"], name: "index_edu_benefits_subs_ytd", using: :btree
  end

  create_table "evss_claims", force: :cascade do |t|
    t.integer  "evss_id",                            null: false
    t.json     "data",                               null: false
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "user_uuid",                          null: false
    t.json     "list_data",          default: {},    null: false
    t.boolean  "requested_decision", default: false, null: false
    t.index ["user_uuid"], name: "index_evss_claims_on_user_uuid", using: :btree
  end

  create_table "form526_job_statuses", force: :cascade do |t|
    t.integer  "form526_submission_id", null: false
    t.string   "job_id",                null: false
    t.string   "job_class",             null: false
    t.string   "status",                null: false
    t.string   "error_class"
    t.string   "error_message"
    t.datetime "updated_at",            null: false
    t.index ["form526_submission_id"], name: "index_form526_job_statuses_on_form526_submission_id", using: :btree
    t.index ["job_id"], name: "index_form526_job_statuses_on_job_id", unique: true, using: :btree
  end

  create_table "form526_opt_ins", force: :cascade do |t|
    t.string   "user_uuid",          null: false
    t.string   "encrypted_email",    null: false
    t.string   "encrypted_email_iv", null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.index ["user_uuid"], name: "index_form526_opt_ins_on_user_uuid", unique: true, using: :btree
  end

  create_table "form526_submissions", force: :cascade do |t|
    t.string   "user_uuid",                                      null: false
    t.integer  "saved_claim_id",                                 null: false
    t.integer  "submitted_claim_id"
    t.string   "encrypted_auth_headers_json",                    null: false
    t.string   "encrypted_auth_headers_json_iv",                 null: false
    t.string   "encrypted_form_json",                            null: false
    t.string   "encrypted_form_json_iv",                         null: false
    t.boolean  "workflow_complete",              default: false, null: false
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.index ["saved_claim_id"], name: "index_form526_submissions_on_saved_claim_id", unique: true, using: :btree
    t.index ["submitted_claim_id"], name: "index_form526_submissions_on_submitted_claim_id", unique: true, using: :btree
    t.index ["user_uuid"], name: "index_form526_submissions_on_user_uuid", using: :btree
  end

  create_table "form_attachments", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.uuid     "guid",                   null: false
    t.string   "encrypted_file_data",    null: false
    t.string   "encrypted_file_data_iv", null: false
    t.string   "type",                   null: false
    t.index ["guid", "type"], name: "index_form_attachments_on_guid_and_type", unique: true, using: :btree
  end

  create_table "gibs_not_found_users", force: :cascade do |t|
    t.string   "edipi",            null: false
    t.string   "first_name",       null: false
    t.string   "last_name",        null: false
    t.string   "encrypted_ssn",    null: false
    t.string   "encrypted_ssn_iv", null: false
    t.datetime "dob",              null: false
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.index ["edipi"], name: "index_gibs_not_found_users_on_edipi", using: :btree
  end

  create_table "health_care_applications", force: :cascade do |t|
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.string   "state",                     default: "pending", null: false
    t.string   "form_submission_id_string"
    t.string   "timestamp"
  end

  create_table "id_card_announcement_subscriptions", force: :cascade do |t|
    t.string   "email",      null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_id_card_announcement_subscriptions_on_email", unique: true, using: :btree
  end

  create_table "in_progress_forms", force: :cascade do |t|
    t.string   "user_uuid",              null: false
    t.string   "form_id",                null: false
    t.string   "encrypted_form_data",    null: false
    t.string   "encrypted_form_data_iv", null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.json     "metadata"
    t.datetime "expires_at"
    t.index ["form_id", "user_uuid"], name: "index_in_progress_forms_on_form_id_and_user_uuid", unique: true, using: :btree
  end

  create_table "invalid_letter_address_edipis", force: :cascade do |t|
    t.string   "edipi",      null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edipi"], name: "index_invalid_letter_address_edipis_on_edipi", using: :btree
  end

  create_table "maintenance_windows", force: :cascade do |t|
    t.string   "pagerduty_id"
    t.string   "external_service"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string   "description"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.index ["end_time"], name: "index_maintenance_windows_on_end_time", using: :btree
    t.index ["pagerduty_id"], name: "index_maintenance_windows_on_pagerduty_id", using: :btree
    t.index ["start_time"], name: "index_maintenance_windows_on_start_time", using: :btree
  end

  create_table "mhv_accounts", force: :cascade do |t|
    t.string   "user_uuid",          null: false
    t.string   "account_state",      null: false
    t.datetime "registered_at"
    t.datetime "upgraded_at"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "mhv_correlation_id"
    t.index ["user_uuid", "mhv_correlation_id"], name: "index_mhv_accounts_on_user_uuid_and_mhv_correlation_id", unique: true, using: :btree
  end

  create_table "notifications", force: :cascade do |t|
    t.integer  "account_id",          null: false
    t.integer  "subject",             null: false
    t.integer  "status"
    t.datetime "status_effective_at"
    t.datetime "read_at"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.index ["account_id", "subject"], name: "index_notifications_on_account_id_and_subject", unique: true, using: :btree
    t.index ["account_id"], name: "index_notifications_on_account_id", using: :btree
    t.index ["status"], name: "index_notifications_on_status", using: :btree
    t.index ["subject"], name: "index_notifications_on_subject", using: :btree
  end

  create_table "persistent_attachments", force: :cascade do |t|
    t.uuid     "guid"
    t.string   "type"
    t.string   "form_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "saved_claim_id"
    t.datetime "completed_at"
    t.string   "encrypted_file_data",    null: false
    t.string   "encrypted_file_data_iv", null: false
    t.index ["guid"], name: "index_persistent_attachments_on_guid", unique: true, using: :btree
    t.index ["saved_claim_id"], name: "index_persistent_attachments_on_saved_claim_id", using: :btree
  end

  create_table "personal_information_logs", force: :cascade do |t|
    t.jsonb    "data",        null: false
    t.string   "error_class", null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["created_at"], name: "index_personal_information_logs_on_created_at", using: :btree
    t.index ["error_class"], name: "index_personal_information_logs_on_error_class", using: :btree
  end

  create_table "preference_choices", force: :cascade do |t|
    t.string   "code"
    t.string   "description"
    t.integer  "preference_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.index ["preference_id"], name: "index_preference_choices_on_preference_id", using: :btree
  end

  create_table "preferences", force: :cascade do |t|
    t.string   "code",       null: false
    t.string   "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_preferences_on_code", unique: true, using: :btree
  end

  create_table "preneed_submissions", force: :cascade do |t|
    t.string   "tracking_number",    null: false
    t.string   "application_uuid"
    t.string   "return_description", null: false
    t.integer  "return_code"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.index ["application_uuid"], name: "index_preneed_submissions_on_application_uuid", unique: true, using: :btree
    t.index ["tracking_number"], name: "index_preneed_submissions_on_tracking_number", unique: true, using: :btree
  end

  create_table "saved_claims", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_form",    null: false
    t.string   "encrypted_form_iv", null: false
    t.string   "form_id"
    t.uuid     "guid",              null: false
    t.string   "type"
    t.index ["created_at", "type"], name: "index_saved_claims_on_created_at_and_type", using: :btree
    t.index ["guid"], name: "index_saved_claims_on_guid", unique: true, using: :btree
  end

  create_table "session_activities", force: :cascade do |t|
    t.uuid     "originating_request_id",                        null: false
    t.string   "originating_ip_address",                        null: false
    t.text     "generated_url",                                 null: false
    t.string   "name",                                          null: false
    t.string   "status",                 default: "incomplete", null: false
    t.uuid     "user_uuid"
    t.string   "sign_in_service_name"
    t.string   "sign_in_account_type"
    t.boolean  "multifactor_enabled"
    t.boolean  "idme_verified"
    t.integer  "duration"
    t.jsonb    "additional_data"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.index ["name"], name: "index_session_activities_on_name", using: :btree
    t.index ["status"], name: "index_session_activities_on_status", using: :btree
    t.index ["user_uuid"], name: "index_session_activities_on_user_uuid", using: :btree
  end

  create_table "terms_and_conditions", force: :cascade do |t|
    t.string   "name"
    t.string   "title"
    t.text     "terms_content"
    t.text     "header_content"
    t.string   "yes_content"
    t.string   "no_content"
    t.string   "footer_content"
    t.string   "version"
    t.boolean  "latest",         default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name", "latest"], name: "index_terms_and_conditions_on_name_and_latest", using: :btree
  end

  create_table "terms_and_conditions_acceptances", id: false, force: :cascade do |t|
    t.string   "user_uuid"
    t.integer  "terms_and_conditions_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_uuid"], name: "index_terms_and_conditions_acceptances_on_user_uuid", using: :btree
  end

  create_table "user_preferences", force: :cascade do |t|
    t.integer  "account_id",           null: false
    t.integer  "preference_id",        null: false
    t.integer  "preference_choice_id", null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["account_id"], name: "index_user_preferences_on_account_id", using: :btree
    t.index ["preference_choice_id"], name: "index_user_preferences_on_preference_choice_id", using: :btree
    t.index ["preference_id"], name: "index_user_preferences_on_preference_id", using: :btree
  end

  create_table "vba_documents_upload_submissions", force: :cascade do |t|
    t.uuid     "guid",                              null: false
    t.string   "status",        default: "pending", null: false
    t.string   "code"
    t.string   "detail"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.boolean  "s3_deleted"
    t.string   "consumer_name"
    t.uuid     "consumer_id"
    t.index ["guid"], name: "index_vba_documents_upload_submissions_on_guid", using: :btree
    t.index ["status"], name: "index_vba_documents_upload_submissions_on_status", using: :btree
  end

  create_table "veteran_organizations", id: false, force: :cascade do |t|
    t.string   "poa",        limit: 3
    t.string   "name"
    t.string   "phone"
    t.string   "state",      limit: 2
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["poa"], name: "index_veteran_organizations_on_poa", unique: true, using: :btree
  end

  create_table "veteran_representatives", id: false, force: :cascade do |t|
    t.string   "representative_id"
    t.string   "poa",               limit: 3
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "phone"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.string   "encrypted_ssn"
    t.string   "encrypted_ssn_iv"
    t.string   "encrypted_dob"
    t.string   "encrypted_dob_iv"
    t.index ["first_name"], name: "index_veteran_representatives_on_first_name", using: :btree
    t.index ["last_name"], name: "index_veteran_representatives_on_last_name", using: :btree
    t.index ["representative_id"], name: "index_veteran_representatives_on_representative_id", unique: true, using: :btree
  end

  create_table "vic_submissions", force: :cascade do |t|
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "state",      default: "pending", null: false
    t.uuid     "guid",                           null: false
    t.json     "response"
    t.index ["guid"], name: "index_vic_submissions_on_guid", unique: true, using: :btree
  end

end
