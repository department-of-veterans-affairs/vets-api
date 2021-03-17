class CreateSpoolFileEvent < ActiveRecord::Migration[6.0]
  def change
    create_table :spool_file_events do |t|
      t.string :rpo
      t.integer :number_of_submissions
      t.string :filename
      t.timestamp :successful_at
      t.integer :retry_attempt

      t.timestamps
    end
  end
end
