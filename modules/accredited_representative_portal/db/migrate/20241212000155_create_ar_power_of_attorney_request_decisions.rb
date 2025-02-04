# frozen_string_literal: true

class CreateArPowerOfAttorneyRequestDecisions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    # Decisions act as a delegated subtype of Resolutions
    # This table stores specific 'decision' types for PowerOfAttorneyRequestResolutions
    create_table :ar_power_of_attorney_request_decisions, id: :uuid do |t|
      t.string 'type', null: false
      t.references 'creator', type: :uuid, foreign_key: { to_table: :user_accounts }, null: false
    end
  end
end

