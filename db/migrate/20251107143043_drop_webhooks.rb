class DropWebhooks < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    drop_table :webhooks_subscriptions, if_exists: true
    drop_table :webhooks_notifications, if_exists: true
    drop_table :webhooks_notification_attempts, if_exists: true
    drop_table :webhooks_notification_attempt_assocs, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
