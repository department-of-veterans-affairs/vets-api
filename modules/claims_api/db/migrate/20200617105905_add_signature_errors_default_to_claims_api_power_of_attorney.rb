class AddSignatureErrorsDefaultToClaimsApiPowerOfAttorney < ActiveRecord::Migration[6.0]
  def change
    change_column_default :claims_api_power_of_attorneys, :signature_errors, []
  end
end
