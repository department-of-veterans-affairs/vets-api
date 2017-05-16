class CreateTermsAndConditions < ActiveRecord::Migration
  def change
    create_table :terms_and_conditions do |t|
      t.string :name
      t.string :title
      t.text :text
      t.string :version
      t.boolean :latest, default: false
      t.timestamps
    end

    create_table :terms_and_conditions_acceptances do |t|
      t.string :user_uuid
      t.references :terms_and_conditions
      t.timestamps
    end
  end
end
