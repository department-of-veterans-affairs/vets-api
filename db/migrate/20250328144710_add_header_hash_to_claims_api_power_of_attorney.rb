class AddHeaderHashToClaimsApiPowerOfAttorney < ActiveRecord::Migration[7.2]
  def change
    add_column :claims_api_power_of_attorneys, :header_hash, :string
  end
end
