class AddClaimsApiProcesses < ActiveRecord::Migration[7.2]
  def change
    create_table :claims_api_processes, id: :uuid do |t|
      t.uuid :processable_id, null: false
      t.string :processable_type, null: false
      t.string :type
      t.string :status
      t.datetime :completed_at
      t.jsonb :errors, default: []

      t.timestamps
    end
  end
end
