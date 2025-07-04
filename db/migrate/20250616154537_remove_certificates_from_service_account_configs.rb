class RemoveCertificatesFromServiceAccountConfigs < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :service_account_configs, :certificates, :string, array: true, default: [], null: false
    end
  end
end
