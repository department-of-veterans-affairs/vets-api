# frozen_string_literal: true

require 'json_marshal/marshaller'

# create_table :saved_claim_group do |t|
#   t.uuid :claim_group_guid, null: false
#   t.integer :parent_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
#   t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
#   t.enum :status, enum_type: 'saved_claim_group_status', default: 'pending'
#   t.jsonb :user_data_ciphertext, comment: 'encrypted data that can be used to identify the associated user'
#   t.text :encrypted_kms_key, comment: 'KMS key used to encrypt the reference data'
#   t.boolean :needs_kms_rotation, default: false, null: false
class SavedClaimGroup < ApplicationRecord
  self.table_name = 'saved_claim_group'

  serialize :user_data, coder: ::JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :user_data, key: :kms_key, **lockbox_options

  after_create { track_event(:create) }
  after_destroy { track_event(:destroy) }

  def parent
    @parent_claim ||= ::SavedClaim.find(parent_claim_id)
  end

  def child
    @child_claim ||= ::SavedClaim.find(saved_claim_id)
  end

  # return all the
  def children
    child_ids = SavedClaimGroup.where(claim_group_guid:, parent_claim_id:).map(&:saved_claim_id)
    ::SavedClaim.where(id: child_ids)
  end

  private

  def track_event(action)
    StatsD.increment('saved_claim_group', tags: ["form_id:#{parent.form_id}", "action:#{action}"])

    parent_claim = "#{parent.form_id} #{parent.id}"
    child_claim = "#{child.form_id} #{child.id}"
    Rails.logger.info("#{self.class} #{action} for #{parent_claim} child #{child_claim}")
  end
end
