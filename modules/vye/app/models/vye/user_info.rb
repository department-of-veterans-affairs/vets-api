# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    class Vye::UserInfo::DobSerializer
      def self.load(v)
        Date.parse(v) if v.present?
      end

      def self.dump(v)
        v.to_s if v.present?
      end
    end

    include GenDigest

    has_many :address_changes, dependent: :destroy
    has_many :awards, dependent: :destroy
    has_many :direct_deposit_changes, dependent: :destroy
    has_many :pending_documents, dependent: :destroy,
                                 primary_key: :ssn_digest,
                                 foreign_key: :ssn_digest,
                                 inverse_of: :user_info
    has_many :verifications, dependent: :destroy

    enum indicator: { chapter1606: 'A', chapter1607: 'E', chapter30: 'B' }

    ENCRYPTED_ATTRIBUTES = %i[
      address_line2 address_line3 address_line4 address_line5 address_line6 dob file_number full_name ssn stub_nm zip
    ].freeze

    has_kms_key
    has_encrypted(*ENCRYPTED_ATTRIBUTES, key: :kms_key, **lockbox_options)

    REQUIRED_ATTRIBUTES = [
      *ENCRYPTED_ATTRIBUTES,
      *%i[
        cert_issue_date date_last_certified del_date fac_code indicator
        mr_status payment_amt rem_ent rpo_code ssn_digest suffix
      ].freeze
    ].freeze

    validates(*REQUIRED_ATTRIBUTES, presence: true)

    serialize :dob, DobSerializer

    before_validation :digest_ssn

    def self.find_and_update_icn(user:) =
      if user.blank?
        nil
      else
        find_by(icn: user.icn) || find_from_digested_ssn(user.ssn).tap do |user_info|
          user_info&.update!(icn: user.icn)
        end
      end

    def self.find_from_digested_ssn(ssn) =
      find_by(ssn_digest: gen_digest(ssn))

    private

    def digest_ssn
      self.ssn_digest = gen_digest(ssn) if ssn_changed?
    end
  end
end
