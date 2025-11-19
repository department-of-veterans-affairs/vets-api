# frozen_string_literal: true

class AddGuidDefaultAndIndexToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    change_column_default :digital_dispute_submissions, :guid, from: nil, to: -> { 'gen_random_uuid()' }
    # Backfill existing records with guids
    safety_assured do
      execute 'UPDATE digital_dispute_submissions SET guid = gen_random_uuid() WHERE guid IS NULL'
      change_column_null :digital_dispute_submissions, :guid, false
    end

    add_index :digital_dispute_submissions, :guid, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :digital_dispute_submissions, :guid, algorithm: :concurrently
    change_column_null :digital_dispute_submissions, :guid, true
    change_column_default :digital_dispute_submissions, :guid, from: -> { 'gen_random_uuid()' }, to: nil
  end
end
