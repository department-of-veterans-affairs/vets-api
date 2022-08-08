class CreateClaimsApiIntentToFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :claims_api_intent_to_files do |t|
      t.string :status
      t.string :cid

      t.timestamps
    end
  end
end
