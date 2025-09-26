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

  # Associations
  belongs_to :parent, class_name: 'SavedClaim', foreign_key: 'parent_claim_id', inverse_of: :parent_of_groups
  belongs_to :child, class_name: 'SavedClaim', foreign_key: 'saved_claim_id', inverse_of: :child_of_groups

  # Scopes
  scope :by_claim_group_guid, ->(guid) { where(claim_group_guid: guid) }
  scope :by_parent_claim, ->(claim_id) { where(parent_claim_id: claim_id) }
  scope :by_child_claim, ->(claim_id) { where(saved_claim_id: claim_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :pending, -> { by_status('pending') }
  scope :needs_kms_rotation, -> { where(needs_kms_rotation: true) }

  # Scope for finding siblings (groups with same parent and claim_group_guid)
  scope :siblings_of, ->(group) { by_claim_group_guid(group.claim_group_guid).by_parent_claim(group.parent_claim_id) }

  after_create { track_event(:create) }
  after_destroy { track_event(:destroy) }

  # Returns all child claims for the same group and parent
  def children
    SavedClaim.joins(:child_of_groups)
              .merge(self.class.siblings_of(self))
  end

  # Returns sibling groups (same parent and claim_group_guid)
  def siblings
    self.class.siblings_of(self).where.not(id: id)
  end

  private

  def track_event(action)
    StatsD.increment('saved_claim_group', tags: ["form_id:#{parent.form_id}", "action:#{action}"])

    parent_claim = "#{parent.form_id} #{parent.id}"
    child_claim = "#{child.form_id} #{child.id}"
    Rails.logger.info("#{self.class} #{action} for #{parent_claim} child #{child_claim}")
  end
end
