class DropPreferredFacilities < ActiveRecord::Migration[6.1]
 def up
     drop_table :preferred_facilities
   end

   def down
     raise ActiveRecord::IrreversibleMigration
   end
end
