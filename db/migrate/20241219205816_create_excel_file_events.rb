class CreateExcelFileEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :excel_file_events do |t|
      t.integer :number_of_submissions
      t.string :filename
      t.timestamp :successful_at
      t.integer :retry_attempt, default: 0
      t.timestamps
      t.index :filename, name: "index_excel_file_events_uniqueness", unique: true
    end
  end
end
