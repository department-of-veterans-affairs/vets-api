class AddPkceToClientConfigs < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :pkce, :boolean
  end
end
