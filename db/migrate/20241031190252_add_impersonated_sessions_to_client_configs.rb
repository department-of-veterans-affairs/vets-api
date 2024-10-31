class AddImpersonatedSessionsToClientConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :client_configs, :impersonated_sessions, :boolean, default: false
  end
end
