class RemoveVirtualAgentUserAccessRecord < ActiveRecord::Migration[6.1]
 def up
     drop_table :virtual_agent_user_access_records
   end

   def down
     raise ActiveRecord::IrreversibleMigration
   end
end
