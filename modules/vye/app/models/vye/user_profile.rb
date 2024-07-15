# frozen_string_literal: true

class Vye::UserProfile < ApplicationRecord
  include Vye::DigestProtected

  has_many :user_infos, dependent: :restrict_with_exception
  has_one(
    :active_user_info,
    -> { with_bdn_clone_active },
    class_name: 'Vye::UserInfo',
    inverse_of: :user_profile,
    dependent: :restrict_with_exception
  )
  has_many :pending_documents, dependent: :restrict_with_exception
  has_many :verifications, dependent: :restrict_with_exception

  digest_attribute :ssn
  digest_attribute :file_number

  validate do
    unless ssn_digest.present? || file_number_digest.present?
      errors.add(
        :base,
        'Either SSN or file number must be present.'
      )
    end
  end

  validates :ssn_digest, :file_number_digest, uniqueness: true, allow_nil: true

  scope(
    :with_assos,
    lambda {
      includes(
        :pending_documents,
        :verifications,
        active_user_info: %i[address_changes awards]
      )
    }
  )

  def self.find_and_update_icn(user:)
    return if user.blank?

    with_assos.find_by(icn: user.icn) || with_assos.find_from_digested_ssn(user.ssn)&.tap do |result|
      result.update!(icn: user.icn)
    end
  end

  def self.find_or_build(attributes)
    ssn, file_number, icn = attributes.values_at(:ssn, :file_number, :icn)
    ssn_digest, file_number_digest = [ssn, file_number].map { |value| gen_digest(value) }

    user_profile = find_by(ssn_digest:) || find_by(file_number_digest:)

    if user_profile.blank?
      user_profile = build(ssn_digest:, file_number_digest:, icn:)
    else
      user_profile.ssn_digest = ssn_digest if user_profile.ssn_digest.blank?
      user_profile.file_number_digest = file_number_digest if user_profile.file_number_digest.blank?
      user_profile.icn = icn if icn.present? && user_profile.icn.blank?
    end

    user_profile.check_for_match(ssn_digest:, file_number_digest:)
  end

  def check_for_match(ssn_digest:, file_number_digest:)
    user_profile = self
    conflict = false
    attribute_name = nil

    if new_record?
      conflict = false
    elsif ssn_digest != attributes['ssn_digest']
      conflict = true
      attribute_name = 'ssn'
      self.ssn_digest = ssn_digest
    elsif file_number_digest != attributes['file_number_digest']
      conflict = true
      attribute_name = 'file_number'
      self.file_number_digest = file_number_digest
    end

    { user_profile:, conflict:, attribute_name: }
  end
end
