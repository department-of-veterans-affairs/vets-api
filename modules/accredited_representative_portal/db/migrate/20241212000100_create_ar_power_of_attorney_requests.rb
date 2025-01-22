# frozen_string_literal: true

class CreateArPowerOfAttorneyRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :ar_power_of_attorney_requests, id: :uuid do |t|
      t.references :claimant, type: :uuid, foreign_key: { to_table: :user_accounts }, null: false
      t.datetime :created_at, null: false
    end
  end
end
