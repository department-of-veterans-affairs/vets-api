class AddIndexHeaderHashToClaimsApiAutoEstablishedClaim < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :claims_api_auto_established_claims, :header_hash, algorithm: :concurrently
  end
end
