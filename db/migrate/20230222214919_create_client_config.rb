class CreateClientConfig < ActiveRecord::Migration[6.1]
  def change
    create_table :client_configs do |t|
      t.string :client_id, null: false, index: { unique: true }
      t.string :authentication, null: false
      t.boolean :anti_csrf, null: false
      t.text :redirect_uri, null: false
      t.interval :access_token_duration, null: false
      t.string :access_token_audience, null: false
      t.interval :refresh_token_duration, null: false
      t.timestamps
    end
  end
end
