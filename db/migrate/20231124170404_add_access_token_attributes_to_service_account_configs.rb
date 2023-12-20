class AddAccessTokenAttributesToServiceAccountConfigs < ActiveRecord::Migration[6.1]
  def change
    add_column :service_account_configs, :access_token_user_attributes, :string, array: true, default: []
  end
end
