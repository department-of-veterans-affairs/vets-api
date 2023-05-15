class AddCertificatesClientConfigs < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :certificates, :string, array: true
  end
end
