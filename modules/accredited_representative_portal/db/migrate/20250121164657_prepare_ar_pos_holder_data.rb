class PrepareArPosHolderData < ActiveRecord::Migration[7.2]

  def change
    safety_assured do
      add_column :ar_power_of_attorney_requests, :accredited_individual_registration_number, :string
      add_column :ar_power_of_attorney_requests, :power_of_attorney_holder_poa_code, :string
    end
  end
end
