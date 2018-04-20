
# frozen_string_literal: true

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

ActiveRecord::Schema.define(version: 20_180_411_001_427) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'vba_documents_upload_submissions', force: :cascade do |t|
    t.string   'status', default: 'pending', null: false
    t.uuid     'guid',                           null: false
    t.datetime 'created_at',                     null: false
    t.datetime 'updated_at',                     null: false
  end

  add_index 'vba_documents_upload_submissions', ['guid'], name: 'index_vba_documents_upload_submissions_on_guid',
                                                          using: :btree
  add_index 'vba_documents_upload_submissions', ['status'], name: 'index_vba_documents_upload_submissions_on_status',
                                                            using: :btree
end
