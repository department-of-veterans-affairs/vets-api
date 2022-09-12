class CreateVirtualAgentUserAccessRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :virtual_agent_user_access_records do |t|
      t.string :action_type, null: false
      t.string :first_name
      t.string :last_name
      t.string :ssn, null: false
      t.string :icn, null: false

      t.index [ "action_type" ],  unique: false
      t.index [ "ssn" ],  unique: false
      t.index [ "icn" ],  unique: false
      t.timestamps
    end
  end
end
