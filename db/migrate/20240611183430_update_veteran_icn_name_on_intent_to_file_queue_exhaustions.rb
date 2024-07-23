class UpdateVeteranIcnNameOnIntentToFileQueueExhaustions < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      rename_column :intent_to_file_queue_exhaustions, :veteran_icn, :user_uuid
      change_column :intent_to_file_queue_exhaustions, :user_uuid, :string, null: false
    end
  end
end
