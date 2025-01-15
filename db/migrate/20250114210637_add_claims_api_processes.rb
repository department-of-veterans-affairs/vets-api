class AddClaimsApiProcesses < ActiveRecord::Migration[7.2]
  def change
    create_table :claims_api_processes, id: :uuid do |t|
      t.uuid :processable_id, null: false
      t.string :processable_type, null: false
      t.string :step_type
      t.string :step_status
      t.datetime :completed_at
      t.jsonb :error_messages, default: []

      t.timestamps
    end
  end
end
