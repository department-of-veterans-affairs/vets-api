class AddGibctInstitutionTypes < ActiveRecord::Migration
  def change
    create_table :institution_types do |t|
      t.string :name, null: false
      t.timestamps null: false

      t.index :name, unique: true
    end
  end
end
