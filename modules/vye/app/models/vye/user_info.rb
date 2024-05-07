# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    include NeedsEnrollmentVerification

    self.ignored_columns +=
      [
        :icn, :ssn_ciphertext, :ssn_digest,                               # moved to UserProfile

        :suffix,                                                          # not needed

        :address_line2_ciphertext, :address_line3_ciphertext,             # moved to AddressChange
        :address_line4_ciphertext, :address_line5_ciphertext,             # moved to AddressChange
        :address_line6_ciphertext, :full_name_ciphertext, :zip_ciphertext # moved to AddressChange
      ]

    belongs_to :user_profile
    belongs_to :bdn_clone

    has_many :address_changes, dependent: :destroy
    has_many :awards, dependent: :destroy
    has_many :direct_deposit_changes, dependent: :destroy

    scope :with_bdn_clone_active, -> { where(bdn_clone_active: true) }

    enum(
      mr_status: { active: 'A', expired: 'E' },
      _suffix: true
    )

    enum(
      indicator: { chapter1606: 'A', chapter1607: 'E', chapter30: 'B', D: 'D' },
      _suffix: true
    )

    delegate :icn, to: :user_profile, allow_nil: true
    delegate :ssn, to: :mpi_profile, allow_nil: true
    delegate :pending_documents, to: :user_profile
    delegate :verifications, to: :user_profile

    has_kms_key
    has_encrypted(:dob, :file_number, :stub_nm, key: :kms_key, **lockbox_options)

    serialize :dob, coder: DateAttributeSerializer

    validates(
      :cert_issue_date, :date_last_certified, :del_date, :dob, :fac_code, :indicator,
      :mr_status, :payment_amt, :rem_ent, :rpo_code, :stub_nm,
      presence: true
    )

    delegate :veteran_name, to: :backend_address

    def backend_address
      address_changes.find_by(origin: 'backend')
    end

    def queued_verifications
      awards.map(&:verifications).flatten
    end

    def queued_verifications?
      queued_verifications.any?
    end

    private

    def mpi_profile
      return @mpi_profile if defined?(@mpi_profile)

      @mpi_profile =
        if icn.blank?
          nil
        else
          MPI::Service
            .new
            .find_profile_by_identifier(
              identifier_type: 'ICN',
              identifier: icn
            )&.profile
        end
    end
  end
end
