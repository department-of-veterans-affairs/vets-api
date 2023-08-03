class AddDescriptionToClientConfigs < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :description, :text
    safety_assured { remove_column :client_configs, :refresh_token_path, :string }
  end
end
