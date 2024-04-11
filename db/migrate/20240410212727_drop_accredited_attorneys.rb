# frozen_string_literal: true

class DropAccreditedAttorneys < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_attorneys, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
