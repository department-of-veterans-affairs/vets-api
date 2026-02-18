# frozen_string_literal: true

class AddMultiPartyFormIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_user_lookup_indexes
    add_association_indexes
  end

  private

  def add_user_lookup_indexes
    # Primary Party lookups (Veteran checks their submissions)
    add_index :multi_party_form_submissions,
              %i[primary_user_uuid status form_type],
              name: 'index_mpf_submissions_on_primary_user_status_form',
              algorithm: :concurrently

    # Secondary Party lookups (physician sees pending forms)
    add_index :multi_party_form_submissions,
              %i[secondary_email status],
              name: 'index_mpf_submissions_on_secondary_email_status',
              algorithm: :concurrently

    add_index :multi_party_form_submissions,
              %i[secondary_user_uuid status],
              name: 'index_mpf_submissions_on_secondary_user_status',
              algorithm: :concurrently

    # Token verification (physician clicks magic link)
    add_index :multi_party_form_submissions,
              %i[id secondary_access_token_expires_at],
              name: 'index_mpf_submissions_on_id_token_expiry',
              algorithm: :concurrently

    # Cleanup queries (find expired/stale submissions by status and age)
    add_index :multi_party_form_submissions,
              %i[status created_at],
              name: 'index_mpf_submissions_on_status_created',
              algorithm: :concurrently
  end

  def add_association_indexes
    add_index :multi_party_form_submissions,
              :primary_in_progress_form_id,
              name: 'index_mpf_submissions_on_primary_form',
              algorithm: :concurrently

    add_index :multi_party_form_submissions,
              :secondary_in_progress_form_id,
              name: 'index_mpf_submissions_on_secondary_form',
              algorithm: :concurrently

    add_index :multi_party_form_submissions,
              :saved_claim_id,
              name: 'index_mpf_submissions_on_saved_claim',
              algorithm: :concurrently
  end
end
