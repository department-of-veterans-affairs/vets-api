class AddCanAcceptDigitalPoaRequestsToVeteranOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :veteran_organizations, :can_accept_digital_poa_requests, :boolean, default: false
  end
end
