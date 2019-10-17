class CreateHigherLevelReview < ActiveRecord::Migration[5.2]
  def change
    create_table :higher_level_reviews do |t|
      t.date :receipt_date
      t.boolean :informal_conference
      t.boolean :same_office
      t.boolean :legacy_opt_in_approved
      t.string :benefit_type
      t.uuid :uuid
      t.references :account
      t.timestamps null: false
    end
  end
end
