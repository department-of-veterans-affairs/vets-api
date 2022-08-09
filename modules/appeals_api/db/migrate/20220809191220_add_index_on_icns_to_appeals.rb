class AddIndexOnIcnsToAppeals < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :appeals_api_higher_level_reviews, :veteran_icn, algorithm: :concurrently
    add_index :appeals_api_notice_of_disagreements, :veteran_icn, algorithm: :concurrently
    add_index :appeals_api_supplemental_claims, :veteran_icn, algorithm: :concurrently
  end
end
