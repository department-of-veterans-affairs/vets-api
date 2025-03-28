class AddHeaderHashToClaimsApiAutoEstablishedClaim < ActiveRecord::Migration[7.2]
  def change
    add_column :claims_api_auto_established_claims, :header_hash, :string
  end
end
