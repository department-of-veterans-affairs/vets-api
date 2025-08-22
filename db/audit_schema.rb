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

ActiveRecord::Schema[7.2].define(version: 2025_05_03_193419) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "audit_user_identifier_types", ["icn", "logingov_uuid", "idme_uuid", "mhv_id", "dslogon_id", "system_hostname"]

  create_table "console1984_commands", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "statements_ciphertext"
    t.text "encrypted_kms_key"
    t.uuid "sensitive_access_id"
    t.uuid "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sensitive_access_id"], name: "index_console1984_commands_on_sensitive_access_id"
    t.index ["session_id", "created_at", "sensitive_access_id"], name: "on_session_and_sensitive_chronologically"
  end

  create_table "console1984_sensitive_accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "justification"
    t.uuid "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_console1984_sensitive_accesses_on_session_id"
  end

  create_table "console1984_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "reason"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_console1984_sessions_on_created_at"
    t.index ["user_id", "created_at"], name: "index_console1984_sessions_on_user_id_and_created_at"
  end

  create_table "console1984_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "username", null: false
    t.string "github_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_console1984_users_on_username"
  end

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
