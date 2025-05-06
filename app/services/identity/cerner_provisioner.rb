# frozen_string_literal: true

require 'map/sign_up/service'

module Identity
  class CernerProvisioner
    include ActiveModel::Validations

    COOKIE_NAME = 'CERNER_CONSENT'
    COOKIE_VALUE = 'ACCEPTED'
    COOKIE_PATH = '/'
    COOKIE_EXPIRATION = 2.minutes
    COOKIE_DOMAIN = '.va.gov'
    VALID_SOURCES = %i[ssoe sis tou].freeze

    attr_reader :icn, :source

    validates :icn, presence: true
    validates :source, inclusion: { in: VALID_SOURCES }, allow_blank: true

    def initialize(icn:, source: nil)
      @icn = icn
      @source = source

      validate!
    rescue ActiveModel::ValidationError => e
      log_provisioner_error(e)
      raise Errors::CernerProvisionerError, e.message
    end

    def perform
      response = update_provisioning

      if response[:agreement_signed].blank?
        Rails.logger.error('[Identity] [CernerProvisioner] update_provisioning error', { icn:, response:, source: })
        raise(Errors::CernerProvisionerError, 'Agreement not accepted')
      end
      if response[:cerner_provisioned].blank?
        Rails.logger.error('[Identity] [CernerProvisioner] update_provisioning error', { icn:, response:, source: })
        raise(Errors::CernerProvisionerError, 'Account not Provisioned')
      end

      Rails.logger.info('[Identity] [CernerProvisioner] update_provisioning success', { icn:, source: })
    rescue Common::Client::Errors::ClientError => e
      log_provisioner_error(e)
      raise Errors::CernerProvisionerError, e.message
    end

    private

    def update_provisioning
      MAP::SignUp::Service.new.update_provisioning(icn:, first_name:, last_name:, mpi_gcids:)
    end

    def log_provisioner_error(error)
      Rails.logger.error("[Identity] [CernerProvisioner] Error: #{error.message}", { icn:, source: })
    end

    def mpi_profile
      @mpi_profile ||= MPI::Service.new.find_profile_by_identifier(identifier: icn,
                                                                   identifier_type: MPI::Constants::ICN)&.profile
    end

    def first_name
      mpi_profile.given_names.first
    end

    def last_name
      mpi_profile.family_name
    end

    def mpi_gcids
      mpi_profile.full_mvi_ids.join('|')
    end
  end
end
