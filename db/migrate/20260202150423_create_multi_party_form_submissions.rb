# frozen_string_literal: true

class CreateMultiPartyFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :multi_party_form_submissions, id: :uuid do |t|
      # Form type and workflow status
      t.string :form_type, null: false
      t.string :status, null: false, default: 'primary_in_progress'

      # Primary party (veteran) information
      t.uuid :primary_user_uuid, null: false
      t.uuid :primary_in_progress_form_id
      t.datetime :primary_completed_at

      # Secondary party (physician) information
      t.string :secondary_email, null: false
      t.uuid :secondary_user_uuid
      t.uuid :secondary_in_progress_form_id
      t.datetime :secondary_completed_at
      t.datetime :secondary_notified_at

      # Access token for secure physician invitation links
      t.text :secondary_access_token_digest
      t.datetime :secondary_access_token_expires_at

      # Reference to final SavedClaim upon submission
      t.bigint :saved_claim_id

      # Submission timestamp
      t.datetime :submitted_at

      # Additional metadata
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    # Indexes for efficient querying
    add_index :multi_party_form_submissions, :primary_user_uuid
    add_index :multi_party_form_submissions, :secondary_user_uuid
    add_index :multi_party_form_submissions, :secondary_email
    add_index :multi_party_form_submissions, :status
    add_index :multi_party_form_submissions, :saved_claim_id
    add_index :multi_party_form_submissions, :form_type
    add_index :multi_party_form_submissions, :secondary_access_token_digest
  end
end
