# frozen_string_literal: true

class EnablePostGisExtension < ActiveRecord::Migration
  def up
    enable_extension('postgis') unless extensions.include?('postgis')
  end
end
