class CreateSignInConfigCertificates < ActiveRecord::Migration[7.2]
  def change
    create_table :sign_in_config_certificates do |t|
      t.belongs_to :config, polymorphic: true, null: false, type: :integer, index: true
      t.belongs_to :certificate, null: false, type: :uuid, index: true
      t.timestamps
    end
  end
end
