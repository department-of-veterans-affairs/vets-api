class CreateSignInCertificates < ActiveRecord::Migration[7.2]
  def change
    create_table :sign_in_certificates, id: :uuid do |t|
      t.text :pem, null: false
      t.timestamps
    end
  end
end
