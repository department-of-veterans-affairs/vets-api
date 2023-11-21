class CreateVBADocumentsMonthlyStats < ActiveRecord::Migration[6.1]
  def change
    create_table :vba_documents_monthly_stats do |t|
      t.integer :month, null: false
      t.integer :year, null: false
      t.jsonb :stats, default: {}

      t.timestamps

      t.index %i[ month year ], name: "index_vba_documents_monthly_stats_uniqueness", unique: true
    end
  end
end
