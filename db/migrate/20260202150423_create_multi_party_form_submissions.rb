# frozen_string_literal: true

class CreateMultiPartyFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :multi_party_form_submissions, id: :uuid do |t|
      t.string :form_type, null: false
      t.string :status, null: false, default: 'primary_in_progress'

      t.uuid :primary_user_uuid, null: false
      t.bigint :primary_in_progress_form_id
      t.datetime :primary_completed_at

      t.string :secondary_email
      t.uuid :secondary_user_uuid
      t.bigint :secondary_in_progress_form_id
      t.datetime :secondary_completed_at
      t.datetime :secondary_notified_at

      t.text :secondary_access_token_digest
      t.datetime :secondary_access_token_expires_at

      t.bigint :saved_claim_id
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
