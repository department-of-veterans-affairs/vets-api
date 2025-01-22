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

ActiveRecord::Schema[7.2].define(version: 2025_01_22_204704) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "logs", force: :cascade do |t|
    t.string "subject_user_identifier", null: false
    t.string "subject_user_identifier_type", null: false
    t.string "acting_user_identifier", null: false
    t.string "acting_user_identifier_type", null: false
    t.string "event_description", null: false
    t.string "event_status", null: false
    t.datetime "event_occurred_at"
    t.jsonb "message", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acting_user_identifier"], name: "index_logs_on_acting_user_identifier"
    t.index ["subject_user_identifier"], name: "index_logs_on_subject_user_identifier"
  end
end
