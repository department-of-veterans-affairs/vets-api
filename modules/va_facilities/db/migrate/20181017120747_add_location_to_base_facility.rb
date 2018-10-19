# frozen_string_literal: true

class AddLocationToBaseFacility < ActiveRecord::Migration
  def change
    add_column :base_facilities, :location, :st_point, geographic: true
  end
end
