class AddCanAcceptDigitalPoaRequestsToAccreditedOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :accredited_organizations, :can_accept_digital_poa_requests, :boolean, default: false, null: false
  end
end
