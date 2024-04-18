class DropPegaTables < ActiveRecord::Migration[7.1]
  def change
    drop_table :pega_tables, if_exists: true
  end
end
