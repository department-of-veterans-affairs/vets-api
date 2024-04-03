# frozen_string_literal: true

class DropAccreditedRepresentativeTypesTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :accredited_representative_types
  end
end
