# frozen_string_literal: true

class AddSignatureErrorsToClaimsApiPowerOfAttorney < ActiveRecord::Migration[6.0]
  def change
    add_column :claims_api_power_of_attorneys, :signature_errors, :string, array: true
  end
end
