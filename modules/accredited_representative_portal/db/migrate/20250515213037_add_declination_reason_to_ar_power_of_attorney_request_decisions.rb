class AddDeclinationReasonToArPowerOfAttorneyRequestDecisions < ActiveRecord::Migration[7.2]
  def change
    add_column :ar_power_of_attorney_request_decisions, :declination_reason, :integer
  end
end
