# frozen_string_literal: true

class CreateArPowerOfAttorneyRequestStatusUpdates < ActiveRecord::Migration[7.1]
  def change
    create_table :ar_power_of_attorney_request_status_updates, id: :uuid do |t|
      t.string 'status_updating_type', null: false
      t.uuid 'status_updating_id', null: false
      t.datetime 'created_at', null: false
    end

    create_table :ar_power_of_attorney_request_replacements, id: :uuid

    create_table :ar_power_of_attorney_request_expirations, id: :uuid

    create_table :ar_power_of_attorney_request_withdrawals, id: :uuid do |t|
      t.text 'reason'
    end

    create_table :ar_power_of_attorney_request_decisions, id: :uuid do |t|
      t.string 'type', null: false
      t.text 'declination_reason'
    end
  end
end
