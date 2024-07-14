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

  scope(
    :with_assos,
    lambda {
      includes(
        :pending_documents,
        :verifications,
        active_user_info: %i[bdn_clone address_changes awards]
      )
    }
  )

  def self.find_and_update_icn(user:)
    return if user.blank?

    with_assos.find_by(icn: user.icn) || with_assos.find_from_digested_ssn(user.ssn)&.tap do |result|
      result.update!(icn: user.icn)
    end
  end

  def confirm_no_conflict(attributes)
    if new_record?
      return { conflict: false }
    elsif gen_digest(attributes[:ssn]) != self.attributes['ssn_digest']
      return { conflict: true, attribute_name: 'ssn' }
    elsif gen_digest(attributes[:file_number]) != self.attributes['file_number_digest']
      return { conflict: true, attribute_name: 'file_number' }
    end

    { conflict: false }
  end

  def self.find_or_build(attributes)
    ssn, file_number, icn = attributes.values_at(:ssn, :file_number, :icn)

    record = find_from_digested_ssn(ssn) || find_from_digested_file_number(file_number)

    if record.blank?
      record = build(attributes)
    else
      record.ssn = ssn if record.ssn_digest.blank?
      record.file_number = file_number if record.file_number_digest.blank?
      record.icn = icn if icn.present? && record.icn.blank?
    end

    record
  end
end
