class CreateDevice < ActiveRecord::Migration[6.1]
  def change
    create_table :devices do |t|
      t.string :key
      t.string :name

      t.timestamps
    end
    add_index :devices, :key, unique: true
  end
end
