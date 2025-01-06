# frozen_string_literal: true

class CreateArPowerOfAttorneyForms < ActiveRecord::Migration[7.1]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    create_table :ar_power_of_attorney_forms, id: :uuid do |t|
      t.references :power_of_attorney_request,
                   type: :uuid,
                   foreign_key: { to_table: :ar_power_of_attorney_requests },
                   null: false,
                   index: { unique: true }

      t.text :encrypted_kms_key, null: false
      t.text :data_ciphertext, null: false
      t.string :city_bidx, null: false
      t.string :state_bidx, null: false
      t.string :zipcode_bidx, null: false
    end

    # Add additional indexes for city, state, and zipcode
    add_index :ar_power_of_attorney_forms,
              [:city_bidx, :state_bidx, :zipcode_bidx],
              algorithm: :concurrently

    add_index :ar_power_of_attorney_forms,
              :zipcode_bidx,
              algorithm: :concurrently
  end
end
