class PgheroQueryStats < ActiveRecord::Migration[6.0]
  def change
    create_table "pghero_query_stats" do |t|
      t.text "database"
      t.text "user"
      t.text "query"
      t.bigint "query_hash"
      t.float "total_time"
      t.bigint "calls"
      t.datetime "captured_at"
      t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
    end
  end
end
