class AddVeteranIcnToClaimsApiAutoEstablishedClaims < ActiveRecord::Migration[6.1]
  def change
    add_column :claims_api_auto_established_claims, :veteran_icn, :string
  end
end
