# frozen_string_literal: true

class DropAccreditedClaimsAgents < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_claims_agents, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
