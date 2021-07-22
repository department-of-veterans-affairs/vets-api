class CreateWebhookTables < ActiveRecord::Migration[6.1]
  def change
    create_table :webhooks_subscriptions do |t|
      t.string :api_name, null: false
      t.string :consumer_name, null: false
      t.uuid :consumer_id, null: false
      t.uuid :api_guid, null: true, default: nil
      t.jsonb :events, default: { subscriptions: [] }
      t.timestamps

      t.index %i[ api_name consumer_id api_guid ], name: "index_webhooks_subscription", unique: true
    end

    create_table :webhooks_notifications do |t|
      t.string :api_name, null: false
      t.string :consumer_name, null: false
      t.uuid :consumer_id, null: false
      t.uuid :api_guid, null: false
      t.string :event, null: false
      t.string :callback_url, null: false
      t.jsonb :msg, null: false
      t.integer :final_attempt_id, null: true, default: nil
      t.integer :processing, default: nil # this is used with the processing job to lock the records. Valid values are null or an epoch timestamp
      t.timestamps

      t.index %i[ api_name consumer_id api_guid event final_attempt_id ], name: "index_wh_notify"
      t.index %i[ final_attempt_id api_name event api_guid ], name: "index_wk_notify_processing"
    end

    create_table :webhooks_notification_attempts do |t|
      t.boolean :success, default: false
      t.jsonb :response, null: false
      t.timestamps
    end

    create_join_table(:webhooks_notifications, :webhooks_notification_attempts, table_name: "webhooks_notification_attempt_assocs") do |t|
      t.index :webhooks_notification_attempt_id, name: 'index_wh_assoc_attempt_id'
      t.index :webhooks_notification_id, name: 'index_wh_assoc_notification_id'
    end
  end
end