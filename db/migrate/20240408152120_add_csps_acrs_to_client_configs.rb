class AddCspsAcrsToClientConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :client_configs, :csps, :string, array: true, default: %w[logingov idme dslogon mhv]
    add_column :client_configs, :acrs, :string, array: true, default: %w[ial1 ial2 loa1 loa3 min]
  end
end
