class AddFlashesToClaimsApiAutoEstablishedClaim < ActiveRecord::Migration[6.0]
  def change
    safety_assured { add_column :claims_api_auto_established_claims, :flashes, :string, array: true, default: [] }
  end
end
