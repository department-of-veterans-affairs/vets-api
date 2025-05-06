class CreateArPowerOfAttorneyRequestWithdrawals < ActiveRecord::Migration[7.2]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    # Withdrawals act as a delegated subtype of Resolutions
    # This table stores specific withdrawal data for PowerOfAttorneyRequestResolutions
    create_table :ar_power_of_attorney_request_withdrawals, id: :uuid do |t|
      t.references 'superseding_power_of_attorney_request',
                   type: :uuid,
                   foreign_key: { to_table: :ar_power_of_attorney_requests }
      t.string 'type', null: false
    end
  end
end
