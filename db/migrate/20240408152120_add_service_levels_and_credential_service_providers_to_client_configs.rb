class AddServiceLevelsAndCredentialServiceProvidersToClientConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :client_configs, :service_levels, :string, array: true, default: %w[ial1 ial2 loa1 loa3 min]
    add_column :client_configs, :credential_service_providers, :string, array: true, default: %w[logingov idme dslogon mhv]
  end
end
