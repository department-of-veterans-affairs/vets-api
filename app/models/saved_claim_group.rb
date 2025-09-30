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
  serialize :user_data, coder: ::JsonMarshal::Marshaller

  has_kms_key
  has_encrypted :user_data, key: :kms_key, **lockbox_options

  belongs_to :parent, class_name: 'SavedClaim', foreign_key: 'parent_claim_id', inverse_of: :parent_of_groups
  belongs_to :child, class_name: 'SavedClaim', foreign_key: 'saved_claim_id', inverse_of: :child_of_groups

  scope :by_claim_group_guid, ->(claim_group_guid) { where(claim_group_guid:) }
  scope :by_saved_claim_id, ->(saved_claim_id) { where(saved_claim_id:) }
  scope :by_parent_id, ->(parent_claim_id) { where(parent_claim_id:) }
  scope :by_status, ->(status) { where(status:) }
  scope :pending, -> { by_status('pending') }
  scope :needs_kms_rotation, -> { where(needs_kms_rotation: true) }
  scope :child_claims_for, ->(parent_id) { where(parent_claim_id: parent_id).where.not(saved_claim_id: parent_id) }

  after_create { track_event(:create) }
  after_destroy { track_event(:destroy) }

  # return all the child claims associated with this group
  def saved_claim_children
    child_ids = SavedClaimGroup.where(claim_group_guid:, parent_claim_id:).map(&:saved_claim_id)
    SavedClaim.where(id: child_ids)
  end

  def parent_claim_group_for_child
    find_by(saved_claim_id: parent.id, parent_claim_id: parent.id)
  end

  def children_of_group
    where(parent_claim_id:).where.not(saved_claim_id: parent_claim_id)
  end

  private

  def track_event(action)
    StatsD.increment('saved_claim_group', tags: ["form_id:#{parent.form_id}", "action:#{action}"])

    parent_claim = "#{parent.form_id} #{parent.id}"
    child_claim = "#{child.form_id} #{child.id}"
    Rails.logger.info("#{self.class} #{action} for #{parent_claim} child #{child_claim}")
  end
end
