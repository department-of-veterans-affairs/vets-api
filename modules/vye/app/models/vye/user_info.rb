# frozen_string_literal: true

module Vye
  class Vye::UserInfo < ApplicationRecord
    include NeedsEnrollmentVerification
    belongs_to :user_profile
    belongs_to :bdn_clone

    has_many :address_changes, dependent: :destroy
    has_many :awards, dependent: :destroy
    has_many :direct_deposit_changes, dependent: :destroy
    has_many :queued_verifications, class_name: 'Verification', inverse_of: :user_info, dependent: :nullify

    scope :with_bdn_clone_active, -> { where(bdn_clone_active: true) }

    delegate :icn, to: :user_profile, allow_nil: true
    delegate :ssn, to: :mpi_profile, allow_nil: true
    delegate :pending_documents, to: :user_profile
    delegate :verifications, to: :user_profile
    delegate :veteran_name, to: :backend_address

    has_kms_key

    has_encrypted(:dob, :file_number, :stub_nm, key: :kms_key, **lockbox_options)

    serialize :dob, coder: DateAttributeSerializer

    validates(
      :fac_code, :indicator, :mr_status, :rem_ent, :rpo_code, :stub_nm,
      presence: true
    )

    def td_number
      return nil unless ssn

      ssn_str = ssn.rjust(9, '0')
      (ssn_str[-2..] + ssn_str[0...-2])
    end

    def backend_address = address_changes.backend.first
    def latest_address = address_changes.latest.first
    def zip_code = backend_address&.zip_code&.slice(0, 5)
    def queued_verifications? = queued_verifications.exists?

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
