
class UpdateStagingEnvPostgis < ActiveRecord::Migration[6.1]
  def up
    if Settings.vsp_environment == "staging"
      connection.execute("SELECT postgis_extensions_upgrade();")
      connection.execute("SELECT postgis_extensions_upgrade();")
    end
  end
end
