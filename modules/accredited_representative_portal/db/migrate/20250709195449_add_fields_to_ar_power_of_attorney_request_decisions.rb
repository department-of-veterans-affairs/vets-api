class AddFieldsToArPowerOfAttorneyRequestDecisions < ActiveRecord::Migration[7.2]
  def change
    add_column :ar_power_of_attorney_request_decisions, :power_of_attorney_holder_type, :string
    add_column :ar_power_of_attorney_request_decisions, :accredited_individual_registration_number, :string
    add_column :ar_power_of_attorney_request_decisions, :power_of_attorney_holder_poa_code, :string
  end
end
