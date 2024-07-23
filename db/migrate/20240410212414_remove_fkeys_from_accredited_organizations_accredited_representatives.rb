# frozen_string_literal: true

class RemoveFkeysFromAccreditedOrganizationsAccreditedRepresentatives < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :accredited_organizations_accredited_representatives, :accredited_representatives,
                       column: :accredited_representative_id, if_exists: true
    remove_foreign_key :accredited_organizations_accredited_representatives, :accredited_organizations,
                       column: :accredited_organization_id, if_exists: true
  end
end
