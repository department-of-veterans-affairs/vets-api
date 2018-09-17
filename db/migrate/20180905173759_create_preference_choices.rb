class CreatePreferenceChoices < ActiveRecord::Migration
  def change
    create_table :preference_choices do |t|
      t.string :code
      t.string :description
      t.integer :preference_id

      t.timestamps null: false
    end
  end
end
