class DropAccreditedIndividualsAccreditedOrganizations < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_individuals_accredited_organizations, if_exists: true
  end
end
