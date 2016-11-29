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

end
