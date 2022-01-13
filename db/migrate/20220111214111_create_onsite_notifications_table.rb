class CreateOnsiteNotificationsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :onsite_notifications do |t|
      t.string 'template_id', null: false
      t.string 'va_profile_id', null: false
      t.boolean 'dismissed', null: false, default: false

      t.timestamps

      t.index ['va_profile_id', 'dismissed'], name: 'show_onsite_notifications_index'
    end
  end
end
