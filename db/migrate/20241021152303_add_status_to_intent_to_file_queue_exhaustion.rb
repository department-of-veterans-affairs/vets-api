class AddStatusToIntentToFileQueueExhaustion < ActiveRecord::Migration[7.1]
  def change
    add_column :intent_to_file_queue_exhaustions, :status, :string, default: 'not_processed'
  end
end
