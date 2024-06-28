# frozen_string_literal: true

require 'map/sign_up/service'

module TermsOfUse
  class Provisioner
    include ActiveModel::Validations

    attr_reader :icn

    validates :icn, presence: true

    def initialize(icn:)
      @icn = icn

      validate!
    rescue ActiveModel::ValidationError => e
      log_provisioner_error(e)
      raise Errors::ProvisionerError, e.message
    end

    def perform
      response = update_provisioning

      if response[:agreement_signed].blank?
        Rails.logger.error('[TermsOfUse] [Provisioner] update_provisioning error', { icn:, response: })
        raise(Errors::ProvisionerError, 'Agreement not accepted')
      end
      if response[:cerner_provisioned].blank?
        Rails.logger.error('[TermsOfUse] [Provisioner] update_provisioning error', { icn:, response: })
        raise(Errors::ProvisionerError, 'Account not Provisioned')
      end
    rescue Common::Client::Errors::ClientError => e
      log_provisioner_error(e)
      raise Errors::ProvisionerError, e.message
    end

    private

    def update_provisioning
      MAP::SignUp::Service.new.update_provisioning(icn:, first_name:, last_name:, mpi_gcids:)
    end

    def log_provisioner_error(error)
      Rails.logger.error("[TermsOfUse] [Provisioner] Error: #{error.message}", { icn: })
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
