# frozen_string_literal: true

class CreateArPowerOfAttorneyRequestResolutions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    create_table :ar_power_of_attorney_request_resolutions, id: :uuid do |t|
      t.references :power_of_attorney_request,
                   type: :uuid,
                   foreign_key: { to_table: :ar_power_of_attorney_requests },
                   null: false,
                   index: { unique: true }
      t.string :resolving_type, null: false
      t.uuid :resolving_id, null: false
      t.text :reason_ciphertext
      t.text :encrypted_kms_key, null: false
      t.datetime :created_at, null: false
    end

    # Add a unique index to ensure one resolution per resolving_type and resolving_id combination
    add_index :ar_power_of_attorney_request_resolutions,
              [:resolving_type, :resolving_id],
              unique: true,
              name: 'unique_resolving_type_and_id',
              algorithm: :concurrently
  end
end
