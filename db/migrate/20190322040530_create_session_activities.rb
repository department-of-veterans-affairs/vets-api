class CreateSessionActivities < ActiveRecord::Migration
  def change
    create_table :session_activities do |t|
      t.uuid     :originating_request_id, null: false
      t.string   :originating_ip_address, null: false
      t.text     :generated_url, null: false
      t.string   :name, null: false
      t.string   :status, null: false, default: 'incomplete'
      t.uuid     :user_uuid
      t.string   :sign_in_service_name
      t.string   :sign_in_account_type
      t.boolean  :multifactor_enabled
      t.boolean  :idme_verified
      t.integer  :duration
      t.jsonb    :additional_data

      t.timestamps null: false
    end
  end
end
