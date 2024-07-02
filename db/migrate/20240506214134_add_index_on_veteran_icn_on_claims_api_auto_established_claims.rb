class AddIndexOnVeteranIcnOnClaimsApiAutoEstablishedClaims < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :claims_api_auto_established_claims, :veteran_icn, algorithm: :concurrently
  end
end
