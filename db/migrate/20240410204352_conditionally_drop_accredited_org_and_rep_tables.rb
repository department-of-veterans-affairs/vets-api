# frozen_string_literal: true

class ConditionallyDropAccreditedOrgAndRepTables < ActiveRecord::Migration[7.1]
  def change
    # First, remove foreign keys to avoid dependency issues during table deletion
    remove_foreign_key :accredited_organizations_accredited_representatives, :accredited_representatives,
                       column: :accredited_representative_id, if_exists: true
    remove_foreign_key :accredited_organizations_accredited_representatives, :accredited_organizations,
                       column: :accredited_organization_id, if_exists: true

    # rubocop:disable Rails/ReversibleMigration
    # Drop join table
    drop_table :accredited_organizations_accredited_representatives, if_exists: true

    # Drop individual tables
    drop_table :accredited_organizations, if_exists: true
    drop_table :accredited_representatives, if_exists: true
    drop_table :accredited_claims_agents, if_exists: true
    drop_table :accredited_attorneys, if_exists: true
    # rubocop:enable Rails/ReversibleMigration
  end
end
