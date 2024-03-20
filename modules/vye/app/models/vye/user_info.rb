# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    INCLUDES = %i[address_changes awards pending_documents verifications].freeze

    self.ignored_columns += %i[
      address_line2_ciphertext address_line3_ciphertext address_line4_ciphertext
      address_line5_ciphertext address_line6_ciphertext
      full_name_ciphertext icn ssn_digest suffix zip_ciphertext
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

    %i[dob file_number ssn stub_nm].freeze.tap do |attributes|
      has_kms_key
      has_encrypted(*attributes, key: :kms_key, **lockbox_options)

      validates(*attributes, presence: true)
    end

    validates(
      :cert_issue_date, :date_last_certified, :del_date, :fac_code, :indicator,
      :mr_status, :payment_amt, :rem_ent, :rpo_code,
      presence: true
    )

    def verification_required
      verifications.empty?
    end

    scope :with_assos, -> { includes(:address_changes, :awards, user_profile: :pending_documents) }
  end
end
