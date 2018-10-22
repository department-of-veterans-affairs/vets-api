# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20181017123903) do

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
  end

  add_index "accounts", ["idme_uuid"], name: "index_accounts_on_idme_uuid", unique: true, using: :btree
  add_index "accounts", ["uuid"], name: "index_accounts_on_uuid", unique: true, using: :btree

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
  end

  add_index "async_transactions", ["source_id"], name: "index_async_transactions_on_source_id", using: :btree
  add_index "async_transactions", ["transaction_id", "source"], name: "index_async_transactions_on_transaction_id_and_source", unique: true, using: :btree
  add_index "async_transactions", ["transaction_id"], name: "index_async_transactions_on_transaction_id", using: :btree
  add_index "async_transactions", ["user_uuid"], name: "index_async_transactions_on_user_uuid", using: :btree

  create_table "base_facilities", id: false, force: :cascade do |t|
    t.string   "unique_id",      null: false
    t.string   "name",           null: false
    t.string   "facility_type",  null: false
    t.string   "classification"
    t.string   "website"
    t.float    "lat",            null: false
    t.float    "long",           null: false
    t.jsonb    "address"
    t.jsonb    "phone"
    t.jsonb    "hours"
    t.jsonb    "services"
    t.jsonb    "feedback"
    t.jsonb    "access"
    t.string   "fingerprint"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "base_facilities", ["unique_id", "facility_type"], name: "index_base_facilities_on_unique_id_and_facility_type", unique: true, using: :btree

  create_table "beta_registrations", force: :cascade do |t|
    t.string   "user_uuid",  null: false
    t.string   "feature",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "beta_registrations", ["user_uuid", "feature"], name: "index_beta_registrations_on_user_uuid_and_feature", unique: true, using: :btree

  create_table "central_mail_submissions", force: :cascade do |t|
    t.string  "state",          default: "pending", null: false
    t.integer "saved_claim_id",                     null: false
  end

  add_index "central_mail_submissions", ["saved_claim_id"], name: "index_central_mail_submissions_on_saved_claim_id", using: :btree
  add_index "central_mail_submissions", ["state"], name: "index_central_mail_submissions_on_state", using: :btree

  create_table "disability_compensation_job_statuses", force: :cascade do |t|
    t.integer  "disability_compensation_submission_id", null: false
    t.string   "job_id",                                null: false
    t.string   "job_class",                             null: false
    t.string   "status",                                null: false
    t.string   "error_message"
    t.datetime "updated_at",                            null: false
  end

  add_index "disability_compensation_job_statuses", ["disability_compensation_submission_id"], name: "index_disability_compensation_job_statuses_on_dsc_id", using: :btree
  add_index "disability_compensation_job_statuses", ["job_id"], name: "index_disability_compensation_job_statuses_on_job_id", unique: true, using: :btree

  create_table "disability_compensation_submissions", force: :cascade do |t|
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "disability_compensation_id"
    t.integer  "va526ez_submit_transaction_id"
  end

  create_table "disability_contentions", force: :cascade do |t|
    t.integer  "code",         null: false
    t.string   "medical_term", null: false
    t.string   "lay_term"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "disability_contentions", ["code"], name: "index_disability_contentions_on_code", unique: true, using: :btree
  add_index "disability_contentions", ["lay_term"], name: "index_disability_contentions_on_lay_term", using: :gin
  add_index "disability_contentions", ["medical_term"], name: "index_disability_contentions_on_medical_term", using: :gin

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
  end

  add_index "education_benefits_claims", ["created_at"], name: "index_education_benefits_claims_on_created_at", using: :btree
  add_index "education_benefits_claims", ["saved_claim_id"], name: "index_education_benefits_claims_on_saved_claim_id", using: :btree
  add_index "education_benefits_claims", ["submitted_at"], name: "index_education_benefits_claims_on_submitted_at", using: :btree

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
  end

  add_index "education_benefits_submissions", ["education_benefits_claim_id"], name: "index_education_benefits_claim_id", unique: true, using: :btree
  add_index "education_benefits_submissions", ["region", "created_at", "form_type"], name: "index_edu_benefits_subs_ytd", using: :btree

  create_table "evss_claims", force: :cascade do |t|
    t.integer  "evss_id",                            null: false
    t.json     "data",                               null: false
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "user_uuid",                          null: false
    t.json     "list_data",          default: {},    null: false
    t.boolean  "requested_decision", default: false, null: false
  end

  add_index "evss_claims", ["user_uuid"], name: "index_evss_claims_on_user_uuid", using: :btree

  create_table "form526_opt_ins", force: :cascade do |t|
    t.string   "user_uuid",          null: false
    t.string   "encrypted_email",    null: false
    t.string   "encrypted_email_iv", null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "form526_opt_ins", ["user_uuid"], name: "index_form526_opt_ins_on_user_uuid", unique: true, using: :btree

  create_table "form_attachments", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.uuid     "guid",                   null: false
    t.string   "encrypted_file_data",    null: false
    t.string   "encrypted_file_data_iv", null: false
    t.string   "type",                   null: false
  end

  add_index "form_attachments", ["guid", "type"], name: "index_form_attachments_on_guid_and_type", unique: true, using: :btree

  create_table "gibs_not_found_users", force: :cascade do |t|
    t.string   "edipi",            null: false
    t.string   "first_name",       null: false
    t.string   "last_name",        null: false
    t.string   "encrypted_ssn",    null: false
    t.string   "encrypted_ssn_iv", null: false
    t.datetime "dob",              null: false
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "gibs_not_found_users", ["edipi"], name: "index_gibs_not_found_users_on_edipi", using: :btree

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
  end

  add_index "id_card_announcement_subscriptions", ["email"], name: "index_id_card_announcement_subscriptions_on_email", unique: true, using: :btree

  create_table "in_progress_forms", force: :cascade do |t|
    t.string   "user_uuid",              null: false
    t.string   "form_id",                null: false
    t.string   "encrypted_form_data",    null: false
    t.string   "encrypted_form_data_iv", null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.json     "metadata"
    t.datetime "expires_at"
  end

  add_index "in_progress_forms", ["form_id", "user_uuid"], name: "index_in_progress_forms_on_form_id_and_user_uuid", unique: true, using: :btree

  create_table "invalid_letter_address_edipis", force: :cascade do |t|
    t.string   "edipi",      null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "invalid_letter_address_edipis", ["edipi"], name: "index_invalid_letter_address_edipis_on_edipi", using: :btree

  create_table "maintenance_windows", force: :cascade do |t|
    t.string   "pagerduty_id"
    t.string   "external_service"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string   "description"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "maintenance_windows", ["end_time"], name: "index_maintenance_windows_on_end_time", using: :btree
  add_index "maintenance_windows", ["pagerduty_id"], name: "index_maintenance_windows_on_pagerduty_id", using: :btree
  add_index "maintenance_windows", ["start_time"], name: "index_maintenance_windows_on_start_time", using: :btree

  create_table "mhv_accounts", force: :cascade do |t|
    t.string   "user_uuid",          null: false
    t.string   "account_state",      null: false
    t.datetime "registered_at"
    t.datetime "upgraded_at"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "mhv_correlation_id"
  end

  add_index "mhv_accounts", ["user_uuid", "mhv_correlation_id"], name: "index_mhv_accounts_on_user_uuid_and_mhv_correlation_id", unique: true, using: :btree

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
  end

  add_index "persistent_attachments", ["guid"], name: "index_persistent_attachments_on_guid", unique: true, using: :btree
  add_index "persistent_attachments", ["saved_claim_id"], name: "index_persistent_attachments_on_saved_claim_id", using: :btree

  create_table "personal_information_logs", force: :cascade do |t|
    t.jsonb    "data",        null: false
    t.string   "error_class", null: false
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "personal_information_logs", ["created_at"], name: "index_personal_information_logs_on_created_at", using: :btree
  add_index "personal_information_logs", ["error_class"], name: "index_personal_information_logs_on_error_class", using: :btree

  create_table "preference_choices", force: :cascade do |t|
    t.string   "code"
    t.string   "description"
    t.integer  "preference_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "preference_choices", ["preference_id"], name: "index_preference_choices_on_preference_id", using: :btree

  create_table "preferences", force: :cascade do |t|
    t.string   "code"
    t.string   "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "preneed_submissions", force: :cascade do |t|
    t.string   "tracking_number",    null: false
    t.string   "application_uuid"
    t.string   "return_description", null: false
    t.integer  "return_code"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "preneed_submissions", ["application_uuid"], name: "index_preneed_submissions_on_application_uuid", unique: true, using: :btree
  add_index "preneed_submissions", ["tracking_number"], name: "index_preneed_submissions_on_tracking_number", unique: true, using: :btree

  create_table "saved_claims", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_form",    null: false
    t.string   "encrypted_form_iv", null: false
    t.string   "form_id"
    t.uuid     "guid",              null: false
    t.string   "type"
  end

  add_index "saved_claims", ["created_at", "type"], name: "index_saved_claims_on_created_at_and_type", using: :btree
  add_index "saved_claims", ["guid"], name: "index_saved_claims_on_guid", unique: true, using: :btree

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
  end

  add_index "terms_and_conditions", ["name", "latest"], name: "index_terms_and_conditions_on_name_and_latest", using: :btree

  create_table "terms_and_conditions_acceptances", id: false, force: :cascade do |t|
    t.string   "user_uuid"
    t.integer  "terms_and_conditions_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "terms_and_conditions_acceptances", ["user_uuid"], name: "index_terms_and_conditions_acceptances_on_user_uuid", using: :btree

  create_table "user_preferences", force: :cascade do |t|
    t.integer  "account_id",           null: false
    t.integer  "preference_id",        null: false
    t.integer  "preference_choice_id", null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "user_preferences", ["account_id"], name: "index_user_preferences_on_account_id", unique: true, using: :btree
  add_index "user_preferences", ["preference_choice_id"], name: "index_user_preferences_on_preference_choice_id", unique: true, using: :btree
  add_index "user_preferences", ["preference_id"], name: "index_user_preferences_on_preference_id", unique: true, using: :btree

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
  end

  add_index "vba_documents_upload_submissions", ["guid"], name: "index_vba_documents_upload_submissions_on_guid", using: :btree
  add_index "vba_documents_upload_submissions", ["status"], name: "index_vba_documents_upload_submissions_on_status", using: :btree

  create_table "vic_submissions", force: :cascade do |t|
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "state",      default: "pending", null: false
    t.uuid     "guid",                           null: false
    t.json     "response"
  end

  add_index "vic_submissions", ["guid"], name: "index_vic_submissions_on_guid", unique: true, using: :btree

end
