# frozen_string_literal: true

class Vye::UserProfile < ApplicationRecord
  include Vye::DigestProtected

  has_many :user_infos, dependent: :destroy

  has_many :pending_documents, dependent: :destroy

  digest_attribute :ssn
  digest_attribute :file_number

  validate :ssn_or_file_number_present

  scope :with_assos, -> { includes(:pending_documents, :user_infos) }

  def active_user_info
    user_infos.first
  end

  def self.find_and_update_icn(user:)
    return if user.blank?

    with_assos.find_by(icn: user.icn) || with_assos.find_from_digested_ssn(user.ssn).tap do |result|
      result&.update!(icn: user.icn)
    end
  end

  private

  def ssn_or_file_number_present
    return true if ssn_digest.present? || file_number_digest.present?

    errors.add(:base, 'Either SSN or file number must be present.')
  end
end
