class RevertItfQueueExhaustionsIcnRename < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      rename_column :intent_to_file_queue_exhaustions, :user_uuid, :veteran_icn
    end
  end
end
