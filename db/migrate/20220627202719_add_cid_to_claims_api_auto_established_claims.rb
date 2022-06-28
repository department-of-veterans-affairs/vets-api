class AddCidToClaimsApiAutoEstablishedClaims < ActiveRecord::Migration[6.1]
  def change
    add_column :claims_api_auto_established_claims, :cid, :string
  end
end
