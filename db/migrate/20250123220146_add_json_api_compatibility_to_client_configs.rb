class AddJsonApiCompatibilityToClientConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :client_configs, :json_api_compatibility, :boolean, null: false, default: true
  end
end
