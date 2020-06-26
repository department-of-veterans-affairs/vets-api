class RemoveDisabilityCompensationSubmissions < ActiveRecord::Migration[5.2]
  def up
    drop_table :disability_compensation_submissions
  end

  def down
    create_table "disability_compensation_submissions", id: :serial, force: :cascade do |t|
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "disability_compensation_id"
      t.integer "va526ez_submit_transaction_id"
      t.boolean "complete", default: false
    end
  end
end
