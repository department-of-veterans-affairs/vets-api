class CreatePreferences < ActiveRecord::Migration[4.2]
  def change
    create_table :preferences do |t|
      t.string :code
      t.string :title

      t.timestamps null: false
    end
  end
end
