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

ActiveRecord::Schema[7.2].define(version: 2025_03_24_180818) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "audit_user_identifier_types", ["icn", "logingov_uuid", "idme_uuid", "mhv_id", "dslogon_id", "system_hostname"]

  create_table "logs", force: :cascade do |t|
    t.string "subject_user_identifier", null: false
    t.enum "subject_user_identifier_type", null: false, enum_type: "audit_user_identifier_types"
    t.string "acting_user_identifier", null: false
    t.enum "acting_user_identifier_type", null: false, enum_type: "audit_user_identifier_types"
    t.string "event_id", null: false
    t.string "event_description", null: false
    t.string "event_status", null: false
    t.datetime "event_occurred_at", null: false
    t.jsonb "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acting_user_identifier"], name: "index_logs_on_acting_user_identifier"
    t.index ["event_id"], name: "index_logs_on_event_id"
    t.index ["subject_user_identifier"], name: "index_logs_on_subject_user_identifier"
  end
end
