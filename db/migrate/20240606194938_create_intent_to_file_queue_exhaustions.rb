class CreateIntentToFileQueueExhaustions < ActiveRecord::Migration[7.1]
  def change
    create_table :intent_to_file_queue_exhaustions do |t|
      t.string :veteran_icn
      t.string :form_type
      t.datetime :form_start_date

      t.timestamps
    end
    add_index :intent_to_file_queue_exhaustions, :veteran_icn
  end
end
