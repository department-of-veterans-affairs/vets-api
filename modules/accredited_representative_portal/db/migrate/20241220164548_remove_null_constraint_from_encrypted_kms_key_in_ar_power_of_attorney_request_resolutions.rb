class RemoveNullConstraintFromEncryptedKmsKeyInArPowerOfAttorneyRequestResolutions < ActiveRecord::Migration[7.2]
  def change
    change_column_null :ar_power_of_attorney_request_resolutions, :encrypted_kms_key, true
  end
end
