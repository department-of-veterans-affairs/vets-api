class AddServiceAccountConfigsArrayDefaults < ActiveRecord::Migration[7.1]
  def change
    change_column_default :service_account_configs, :scopes, from: nil, to: []
    change_column_default :service_account_configs, :certificates, from: nil, to: []
  end
end
