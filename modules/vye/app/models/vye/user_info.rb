# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    INCLUDES = %i[address_changes awards pending_documents verifications].freeze

    self.ignored_columns +=
      [
        :ssn_digest, :icn, # moved to UserProfile

        :suffix, # not needed

        :address_line2_ciphertext, :address_line3_ciphertext,             # moved to AddressChange
        :address_line4_ciphertext, :address_line5_ciphertext,             # moved to AddressChange
        :address_line6_ciphertext, :full_name_ciphertext, :zip_ciphertext # moved to AddressChange
      ]

    belongs_to :user_profile

    has_many :address_changes, dependent: :destroy
    has_many :awards, dependent: :destroy
    has_many :direct_deposit_changes, dependent: :destroy
    has_many :verifications, dependent: :destroy

    accepts_nested_attributes_for :address_changes, :awards, :direct_deposit_changes, :verifications

    enum mr_status: { active: 'A', expired: 'E' }

    enum indicator: { chapter1606: 'A', chapter1607: 'E', chapter30: 'B', D: 'D' }

    serialize :dob, coder: DobSerializer

    delegate :icn, to: :user_profile, allow_nil: true
    delegate :pending_documents, to: :user_profile, allow_nil: true

    has_kms_key
    has_encrypted(:file_number, :ssn, :dob, :stub_nm, key: :kms_key, **lockbox_options)

    validates :dob, :stub_nm, presence: true

    validate :ssn_or_file_number_present

    validates(
      :cert_issue_date, :date_last_certified, :del_date, :fac_code, :indicator,
      :mr_status, :payment_amt, :rem_ent, :rpo_code,
      presence: true
    )

    def verification_required
      verifications.empty?
    end

    def ssn_or_file_number_present
      return true if ssn.present? || file_number.present?

      errors.add(:base, 'Either SSN or file number must be present.')
    end

    scope :with_assos, -> { includes(:address_changes, :awards, user_profile: :pending_documents) }
  end
end
