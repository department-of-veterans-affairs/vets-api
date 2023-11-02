class UpdateStagingPostgis < ActiveRecord::Migration[6.1]
  def up
    if Settings.vsp_enviroment == "staging"
      connection.execute("SELECT postgis_extensions_upgrade();")
      connection.execute("SELECT postgis_extensions_upgrade();")
    end
  end
end
