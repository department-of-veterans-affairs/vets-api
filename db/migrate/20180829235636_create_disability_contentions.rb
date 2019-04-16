class CreateDisabilityContentions < ActiveRecord::Migration[4.2]
  def change
    create_table :disability_contentions do |t|
      t.integer :code, null: false, unique: true
      t.string :medical_term, null: false
      t.string :lay_term

      t.timestamps null: false
    end
  end
end
