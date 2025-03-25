class AddSha256ToClaimsApiPowerOfAttorneys < ActiveRecord::Migration[7.2]
  def change
    add_column :claims_api_power_of_attorneys, :sha256, :string
  end
end
