# frozen_string_literal: true
# This migration comes from vye (originally 20231120034926)

class CreateVyePendingDocuments < ActiveRecord::Migration[6.1]
  def change
    create_table :vye_pending_documents do |t|
      t.string :ssn_digest
      t.text :ssn_ciphertext
      t.string :claim_no_ciphertext
      t.string :doc_type
      t.datetime :queue_date
      t.string :rpo

      t.text :encrypted_kms_key
      t.timestamps

      t.index :ssn_digest
    end
  end
end
