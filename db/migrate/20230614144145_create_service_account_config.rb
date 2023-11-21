class CreateServiceAccountConfig < ActiveRecord::Migration[6.1]
  def change
    create_table :service_account_configs do |t|
      t.string :service_account_id, null: false, index: { unique: true }
      t.text :description, null: false
      t.text :scopes, array: true, null: false
      t.string :access_token_audience, null: false
      t.interval :access_token_duration, null: false
      t.string :certificates, array: true
      t.timestamps
    end
  end
end

