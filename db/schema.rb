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

ActiveRecord::Schema.define(version: 20161128193206) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "disability_claims", force: :cascade do |t|
    t.integer  "evss_id",                            null: false
    t.json     "data",                               null: false
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "user_uuid",                          null: false
    t.json     "list_data",          default: {},    null: false
    t.boolean  "requested_decision", default: false, null: false
  end

  add_index "disability_claims", ["user_uuid"], name: "index_disability_claims_on_user_uuid", using: :btree

  create_table "education_benefits_claims", force: :cascade do |t|
    t.datetime "submitted_at"
    t.datetime "processed_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "encrypted_form",             null: false
    t.string   "encrypted_form_iv",          null: false
    t.string   "regional_processing_office", null: false
  end

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
  end

  add_index "education_benefits_submissions", ["education_benefits_claim_id"], name: "index_education_benefits_claim_id", unique: true, using: :btree
  add_index "education_benefits_submissions", ["region", "created_at"], name: "index_education_benefits_submissions_on_region_and_created_at", using: :btree

  create_table "institution_types", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "institution_types", ["name"], name: "index_institution_types_on_name", unique: true, using: :btree

  create_table "institutions", force: :cascade do |t|
    t.integer  "institution_type_id"
    t.string   "facility_code"
    t.string   "institution"
    t.string   "city"
    t.string   "state"
    t.string   "zip"
    t.string   "country"
    t.float    "bah"
    t.string   "cross"
    t.string   "ope"
    t.string   "insturl"
    t.string   "vet_tuition_policy_url"
    t.integer  "pred_degree_awarded"
    t.integer  "locale"
    t.integer  "gibill",                                              default: 0
    t.integer  "undergrad_enrollment"
    t.boolean  "yr",                                                  default: false
    t.boolean  "student_veteran",                                     default: false
    t.string   "student_veteran_link"
    t.boolean  "poe",                                                 default: false
    t.boolean  "eight_keys",                                          default: false
    t.boolean  "dodmou",                                              default: false
    t.boolean  "sec_702",                                             default: false
    t.string   "vetsuccess_name"
    t.string   "vetsuccess_email"
    t.string   "credit_for_mil_training"
    t.string   "vet_poc"
    t.string   "student_vet_grp_ipeds"
    t.string   "soc_member"
    t.string   "va_highest_degree_offered"
    t.float    "retention_rate_veteran_ba"
    t.float    "retention_all_students_ba"
    t.float    "retention_rate_veteran_otb"
    t.float    "retention_all_students_otb"
    t.float    "persistance_rate_veteran_ba"
    t.float    "persistance_rate_veteran_otb"
    t.float    "graduation_rate_veteran"
    t.float    "graduation_rate_all_students"
    t.float    "transfer_out_rate_veteran"
    t.float    "transfer_out_rate_all_students"
    t.float    "salary_all_students"
    t.float    "repayment_rate_all_students"
    t.float    "avg_stu_loan_debt"
    t.string   "calendar"
    t.float    "tuition_in_state"
    t.float    "tuition_out_of_state"
    t.float    "books"
    t.string   "online_all"
    t.float    "p911_tuition_fees",                                   default: 0.0
    t.integer  "p911_recipients",                                     default: 0
    t.float    "p911_yellow_ribbon",                                  default: 0.0
    t.integer  "p911_yr_recipients",                                  default: 0
    t.boolean  "accredited",                                          default: false
    t.string   "accreditation_type"
    t.string   "accreditation_status"
    t.string   "caution_flag"
    t.string   "caution_flag_reason"
    t.integer  "complaints_facility_code",                            default: 0
    t.integer  "complaints_financial_by_fac_code",                    default: 0
    t.integer  "complaints_quality_by_fac_code",                      default: 0
    t.integer  "complaints_refund_by_fac_code",                       default: 0
    t.integer  "complaints_marketing_by_fac_code",                    default: 0
    t.integer  "complaints_accreditation_by_fac_code",                default: 0
    t.integer  "complaints_degree_requirements_by_fac_code",          default: 0
    t.integer  "complaints_student_loans_by_fac_code",                default: 0
    t.integer  "complaints_grades_by_fac_code",                       default: 0
    t.integer  "complaints_credit_transfer_by_fac_code",              default: 0
    t.integer  "complaints_credit_job_by_fac_code",                   default: 0
    t.integer  "complaints_job_by_fac_code",                          default: 0
    t.integer  "complaints_transcript_by_fac_code",                   default: 0
    t.integer  "complaints_other_by_fac_code",                        default: 0
    t.integer  "complaints_main_campus_roll_up",                      default: 0
    t.integer  "complaints_financial_by_ope_id_do_not_sum",           default: 0
    t.integer  "complaints_quality_by_ope_id_do_not_sum",             default: 0
    t.integer  "complaints_refund_by_ope_id_do_not_sum",              default: 0
    t.integer  "complaints_marketing_by_ope_id_do_not_sum",           default: 0
    t.integer  "complaints_accreditation_by_ope_id_do_not_sum",       default: 0
    t.integer  "complaints_degree_requirements_by_ope_id_do_not_sum", default: 0
    t.integer  "complaints_student_loans_by_ope_id_do_not_sum",       default: 0
    t.integer  "complaints_grades_by_ope_id_do_not_sum",              default: 0
    t.integer  "complaints_credit_transfer_by_ope_id_do_not_sum",     default: 0
    t.integer  "complaints_jobs_by_ope_id_do_not_sum",                default: 0
    t.integer  "complaints_transcript_by_ope_id_do_not_sum",          default: 0
    t.integer  "complaints_other_by_ope_id_do_not_sum",               default: 0
    t.datetime "created_at",                                                          null: false
    t.datetime "updated_at",                                                          null: false
  end

  add_index "institutions", ["city"], name: "index_institutions_on_city", using: :btree
  add_index "institutions", ["facility_code"], name: "index_institutions_on_facility_code", using: :btree
  add_index "institutions", ["institution"], name: "index_institutions_on_institution", using: :btree
  add_index "institutions", ["institution_type_id"], name: "index_institutions_on_institution_type_id", using: :btree
  add_index "institutions", ["state"], name: "index_institutions_on_state", using: :btree

end
