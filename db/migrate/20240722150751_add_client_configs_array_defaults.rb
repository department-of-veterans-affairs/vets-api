class AddClientConfigsArrayDefaults < ActiveRecord::Migration[7.1]
  def change
    change_column_default :client_configs, :certificates, from: nil, to: []
  end
end
