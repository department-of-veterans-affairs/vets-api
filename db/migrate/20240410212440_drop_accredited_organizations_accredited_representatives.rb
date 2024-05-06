# frozen_string_literal: true

class DropAccreditedOrganizationsAccreditedRepresentatives < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_organizations_accredited_representatives, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
