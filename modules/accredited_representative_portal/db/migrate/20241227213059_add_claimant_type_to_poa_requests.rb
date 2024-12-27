class AddClaimantTypeToPoaRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :ar_power_of_attorney_requests, :claimant_type, :string, null: false
  end
end
