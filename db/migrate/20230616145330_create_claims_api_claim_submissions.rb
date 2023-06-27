class CreateClaimsApiClaimSubmissions < ActiveRecord::Migration[6.1]
  def change
    create_table :claims_api_claim_submissions do |t|
      t.references :claim, type: :uuid, null: false, index: true, foreign_key: { to_table: :claims_api_auto_established_claims }
      t.string :claim_type, null: false
      t.string :consumer_label, null: false

      t.timestamps
    end
  end
end
