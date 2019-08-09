# frozen_string_literal: true

class EnablePostGisExtension < ActiveRecord::Migration[4.2]
  def up
    enable_extension('postgis') unless extensions.include?('postgis')
  end

  def down
    disable_extension('postgis') if extensions.include?('postgis')
  end
end
