# frozen_string_literal: true

class CreateEventLogs < ActiveRecord::Migration
  def change
    create_table :event_logs do |t|
      t.uuid :request_id, null: false, unique: true
      t.string :type
      t.string :ip_address
      t.string :state
      t.string :user_uuid
      t.string :session_id
      t.string :description
      t.string :reference_class
      t.string :reference_id
      t.jsonb  :data

      t.timestamps null: false
    end
  end
end
