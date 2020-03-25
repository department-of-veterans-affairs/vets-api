# frozen_string_literal: true

class AddDefaultVbmsFailureCountToClaimsApiPowerOfAttorneys < ActiveRecord::Migration[5.2]
  def up
    change_column_default :claims_api_power_of_attorneys, :vbms_upload_failure_count, 0
  end

  def down
    change_column_default :claims_api_power_of_attorneys, :vbms_upload_failure_count, nil
  end
end
