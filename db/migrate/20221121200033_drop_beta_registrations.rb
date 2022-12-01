class DropBetaRegistrations < ActiveRecord::Migration[6.1]
 def up
     drop_table :beta_registrations
   end

   def down
     raise ActiveRecord::IrreversibleMigration
   end
end
