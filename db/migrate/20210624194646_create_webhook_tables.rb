class CreateWebhookTables < ActiveRecord::Migration[6.1]
  def change
    create_table :webhook_subscriptions do |t|
      t.string :api_name, null: false
      t.string :consumer_name, null: false
      t.uuid :consumer_id, null: false
      t.uuid :api_guid, null: true, default: nil
      t.jsonb :events, default: { subscriptions: [] }
      t.timestamps

      t.index %i[ api_name consumer_id api_guid ], name: "index_webhook_subscription", unique: true
    end

    create_table :webhook_notifications do |t|
      t.string :api_name, null: false
      t.string :consumer_name, null: false
      t.uuid :consumer_id, null: false
      t.uuid :api_guid, null: false
      t.string :event, null: false
      t.string :callback_url, null: false
      t.jsonb :msg, null: false
      t.jsonb :attempts, null: false, default: []  # [[654456456, {response_code: 200, wn_ids: [444,555,111]}]]
      t.boolean :complete, default: false # response.success?, response.status_code, *ids
      t.timestamps

      t.index %i[ api_name consumer_id api_guid event complete ], name: "index_webhook_notification"
    end
  end
end
