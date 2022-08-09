class AddVeteranIcnToAppeals < ActiveRecord::Migration[6.1]
  def change
    add_column :appeals_api_higher_level_reviews, :veteran_icn, :string, null: true
    add_column :appeals_api_notice_of_disagreements, :veteran_icn, :string, null: true
    add_column :appeals_api_supplemental_claims, :veteran_icn, :string, null: true
  end
end
