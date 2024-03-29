# frozen_string_literal: true

class Vye::UserProfile < ApplicationRecord
  include Vye::DigestProtected

  has_many :user_infos, dependent: :restrict_with_exception

  has_many(
    :active_user_infos,
    lambda {
      order(created_at: :desc).limit(1)
    },
    class_name: 'Vye::UserInfo', inverse_of: :user_profile,
    dependent: :restrict_with_exception
  )

  has_many :pending_documents, dependent: :restrict_with_exception

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

  scope :with_assos, -> { includes(:pending_documents, active_user_infos: %i[address_changes awards verifications]) }

  def active_user_info
    active_user_infos.first
  end

  def self.find_and_update_icn(user:)
    return if user.blank?

    with_assos.find_by(icn: user.icn) || with_assos.find_from_digested_ssn(user.ssn)&.tap do |result|
      result.update!(icn: user.icn)
    end
  end

  def self.produce(attributes)
    attributes = attributes.slice(:ssn, :file_number, :icn)

    %i[ssn file_number].each do |key|
      send("find_from_digested_#{key}", attributes[key])&.then { |record| return record if record.update!(attributes) }
    end

    build(attributes)
  end
end
