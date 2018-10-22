# frozen_string_literal: true

class EnablePostGISExtension < ActiveRecord::Migration
  def up
    enable_extension('postgis') unless extensions.include?('postgis')
  end
end
