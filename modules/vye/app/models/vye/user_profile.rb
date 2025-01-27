# frozen_string_literal: true

class Vye::UserProfile < ApplicationRecord
  STATSD_PREFIX = name.gsub('::', '.').underscore
  STATSD_NAMES =
    {
      icn_hit: "#{STATSD_PREFIX}.icn_hit",
      icn_miss: "#{STATSD_PREFIX}.icn_miss",
      ssn_hit: "#{STATSD_PREFIX}.ssn_hit",
      ssn_miss: "#{STATSD_PREFIX}.ssn_miss",
      icn_and_ssn_miss: "#{STATSD_PREFIX}.icn_and_ssn_miss",
      active_user_info_hit: "#{STATSD_PREFIX}.active_user_info_hit",
      active_user_info_miss: "#{STATSD_PREFIX}.active_user_info_miss"
    }.freeze

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

  def confirm_active_user_info_present?
    if active_user_info.blank?
      Rails.logger.error "#{self.class.name}: There is no active_user_info for id##{id}."
      StatsD.increment(STATSD_NAMES[:active_user_info_miss])
      false
    else
      StatsD.increment(STATSD_NAMES[:active_user_info_hit])
      true
    end
  end

  def self.find_and_update_icn(user:)
    if user.blank?
      Rails.logger.error "#{name}: There is no user in session."
      return
    end

    unless user.loa3?
      Rails.logger.error "#{name}: The user(#{user&.user_account&.id}) in session is not LOA3."
      return
    end

    if user.ssn.blank?
      Rails.logger.error "#{name}: The user(#{user&.user_account&.id}) in session does not have an SSN."
      return
    end

    if user.icn.blank?
      Rails.logger.error "#{name}: The user(#{user&.user_account&.id}) in session does not have an ICN."
      return
    end

    user_profile = with_assos.find_by(icn: user.icn)
    if user_profile
      StatsD.increment(STATSD_NAMES[:icn_hit])

      return unless user_profile.confirm_active_user_info_present?

      return user_profile
    else
      StatsD.increment(STATSD_NAMES[:icn_miss])
    end

    user_profile = with_assos.find_from_digested_ssn(user.ssn)
    if user_profile
      user_profile.update!(icn: user.icn)
      StatsD.increment(STATSD_NAMES[:ssn_hit])

      return unless user_profile.confirm_active_user_info_present?

      return user_profile
    else
      StatsD.increment(STATSD_NAMES[:ssn_miss])
    end

    Rails.logger.warn "#{name}: The user(#{user&.user_account&.id}) in session could not find by ICN or SSN."

    nil
  end

  def self.produce(attributes)
    ssn, file_number, icn = attributes.values_at(:ssn, :file_number, :icn).map(&:presence)
    ssn_digest, file_number_digest = [ssn, file_number].map { |value| gen_digest(value) }
    assignment = { ssn_digest:, file_number_digest: }.merge(icn.present? ? { icn: } : {})

    user_profile = find_or_build(ssn_digest:, file_number_digest:)
    user_profile&.assign_attributes(**assignment)

    user_profile
  end

  def self.find_or_build(ssn_digest:, file_number_digest:)
    return nil if ssn_digest.blank? && file_number_digest.blank?

    result = find_by(ssn_digest:) if ssn_digest.present?
    return result if result.present?

    result = find_by(file_number_digest:) if file_number_digest.present?
    return result if result.present?

    build(ssn_digest:, file_number_digest:)
  end
end
