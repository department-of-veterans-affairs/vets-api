# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    include NeedsEnrollmentVerification

    belongs_to :user_profile
    belongs_to :bdn_clone

    has_many :address_changes, dependent: :destroy

    has_one(
      :backend_address,
      -> { where(origin: 'backend') },
      class_name: 'AddressChange',
      inverse_of: :user_info,
      dependent: :restrict_with_exception
    )

    has_one(
      :latest_address,
      -> { order(created_at: :desc) },
      class_name: 'AddressChange',
      inverse_of: :user_info,
      dependent: :restrict_with_exception
    )

    has_many :awards, dependent: :destroy
    has_many :direct_deposit_changes, dependent: :destroy

    scope :with_bdn_clone_active, -> { where(bdn_clone_active: true) }

    enum(
      mr_status: { active: 'A', expired: 'E' },
      _prefix: :mr_status
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

    def zip_code
      backend_address&.zip_code&.slice(0, 5)
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
