# frozen_string_literal: true

class DropAccreditedRepresentatives < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_representatives, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
