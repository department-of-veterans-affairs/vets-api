class CreateArSavedClaimClaimantRepresentatives < ActiveRecord::Migration[7.2]
  def change
    create_table :ar_saved_claim_claimant_representatives, id: :uuid do |t|
      t.belongs_to :saved_claim, null: false, index: { unique: true }

      ##
      # This and corresponding PK should have PG's `uuid` type?
      #
      t.string "claimant_id", null: false
      t.string "claimant_type", null: false

      t.string "power_of_attorney_holder_type", null: false
      t.string "power_of_attorney_holder_poa_code", null: false

      t.string "accredited_individual_registration_number", null: false

      t.datetime "created_at", null: false
    end
  end
end
