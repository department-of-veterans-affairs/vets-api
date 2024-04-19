# frozen_string_literal: true

class DropAccreditedOrganizations < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_organizations, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
