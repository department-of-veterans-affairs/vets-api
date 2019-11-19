class AddVbmsIdFieldsToClaimsApiPowerOfAttorney < ActiveRecord::Migration[5.2]
  def change
    add_column :claims_api_power_of_attorneys, :vbms_new_document_version_ref_id, :string
    add_column :claims_api_power_of_attorneys, :vbms_document_series_ref_id, :string
    add_column :claims_api_power_of_attorneys, :vbms_error_message, :string
    add_column :claims_api_power_of_attorneys, :vbms_upload_failure_count, :integer
  end
end
