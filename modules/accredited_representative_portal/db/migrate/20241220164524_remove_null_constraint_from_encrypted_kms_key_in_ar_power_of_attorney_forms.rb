class RemoveNullConstraintFromEncryptedKmsKeyInArPowerOfAttorneyForms < ActiveRecord::Migration[7.2]
  def change
    change_column_null :ar_power_of_attorney_forms, :encrypted_kms_key, true
  end
end
