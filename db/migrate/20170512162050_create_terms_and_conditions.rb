class CreateTermsAndConditions < ActiveRecord::Migration
  safety_assured

  def change
    create_table :terms_and_conditions do |t|
      t.string :name
      t.string :title
      t.text :terms_content
      t.text :header_content
      t.string :yes_content
      t.string :no_content
      t.string :footer_content
      t.string :version
      t.boolean :latest, default: false
      t.timestamps
    end
    add_index :terms_and_conditions, [:name, :latest]

    create_table :terms_and_conditions_acceptances, id: false do |t|
      t.string :user_uuid
      t.references :terms_and_conditions
      t.timestamps
    end
    add_index :terms_and_conditions_acceptances, [:user_uuid]
  end
end
