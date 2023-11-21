class AddAccessTokenAttributesToClientConfigs < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :access_token_attributes, :string, default: [], array: true
  end
end
