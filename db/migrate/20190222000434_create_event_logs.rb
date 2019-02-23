# frozen_string_literal: true

class CreateEventLogs < ActiveRecord::Migration
  def change
    create_table :event_logs do |t|
      t.uuid :request_id, null: false, unique: true
      t.string :type
      t.string :ip_address
      t.string :state
      t.string :description
      t.jsonb  :data

      # Optional Foreign Key Ids
      t.integer :account_id
      t.integer :event_log_id # polymorphic relationship to other STI subclasses

      t.timestamps null: false
    end
  end
end
