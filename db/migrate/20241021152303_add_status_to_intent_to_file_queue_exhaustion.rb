class AddStatusToIntentToFileQueueExhaustion < ActiveRecord::Migration[7.1]
  def change
    create_enum :itf_remediation_status, %w[unprocessed]

    add_column :intent_to_file_queue_exhaustions, :status, :enum, enum_type: 'itf_remediation_status', default: 'unprocessed'
  end
end
