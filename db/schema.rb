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

ActiveRecord::Schema.define(version: 20170209223501) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "education_benefits_claims", force: :cascade do |t|
    t.datetime "submitted_at"
    t.datetime "processed_at"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "encrypted_form",                              null: false
    t.string   "encrypted_form_iv",                           null: false
    t.string   "regional_processing_office",                  null: false
    t.string   "form_type",                  default: "1990", null: false
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
    t.string   "form_type",                   default: "1990",      null: false
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

  create_table "form_profiles", force: :cascade do |t|
    t.uuid     "user_uuid",                 null: false
    t.string   "encrypted_form_profile",    null: false
    t.string   "encrypted_form_profile_iv", null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "form_profiles", ["user_uuid"], name: "index_form_profiles_on_user_uuid", using: :btree

  create_table "in_progress_forms", force: :cascade do |t|
    t.uuid     "user_uuid",              null: false
    t.string   "form_id",                null: false
    t.string   "encrypted_form_data",    null: false
    t.string   "encrypted_form_data_iv", null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "in_progress_forms", ["form_id"], name: "index_in_progress_forms_on_form_id", using: :btree
  add_index "in_progress_forms", ["user_uuid"], name: "index_in_progress_forms_on_user_uuid", using: :btree

end
