# frozen_string_literal: true

class CreateArPowerOfAttorneyRequestExpirations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    # Expirations act as a delegated subtype of Resolutions
    # This table tracks expiration records for PowerOfAttorneyRequestResolutions
    create_table :ar_power_of_attorney_request_expirations, id: :uuid
  end
end

