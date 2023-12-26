class RemoveTermsAndConditions < ActiveRecord::Migration[6.1]
  def up
    drop_table :terms_and_conditions
    drop_table :terms_and_conditions_acceptances
  end

  def down
    create_table "terms_and_conditions", id: :serial, force: :cascade do |t|
      t.string "name"
      t.string "title"
      t.text "terms_content"
      t.text "header_content"
      t.string "yes_content"
      t.string "no_content"
      t.string "footer_content"
      t.string "version"
      t.boolean "latest", default: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["name", "latest"], name: "index_terms_and_conditions_on_name_and_latest"
    end

    create_table "terms_and_conditions_acceptances", id: false, force: :cascade do |t|
      t.string "user_uuid"
      t.integer "terms_and_conditions_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.uuid "user_account_id"
      t.index ["user_account_id"], name: "index_terms_and_conditions_acceptances_on_user_account_id"
      t.index ["user_uuid"], name: "index_terms_and_conditions_acceptances_on_user_uuid"
    end
  end
end
