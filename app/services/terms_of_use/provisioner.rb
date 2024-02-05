# frozen_string_literal: true

require 'map/sign_up/service'

module TermsOfUse
  class Provisioner
    include ActiveModel::Validations

    attr_reader :icn, :first_name, :last_name, :mpi_gcids

    validates :icn, :first_name, :last_name, :mpi_gcids, presence: true

    def initialize(icn:, first_name:, last_name:, mpi_gcids:)
      @icn = icn
      @first_name = first_name
      @last_name = last_name
      @mpi_gcids = mpi_gcids

      validate!
    rescue ActiveModel::ValidationError => e
      log_provisioner_error(e)
      raise Errors::ProvisionerError, e.message
    end

    def perform
      response = update_provisioning
      raise(Errors::ProvisionerError, 'Agreement not accepted') if response[:agreement_signed].blank?

      ActiveModel::Type::Boolean.new.cast(response[:agreement_signed])
    rescue Common::Client::Errors::ClientError => e
      log_provisioner_error(e)
      raise Errors::ProvisionerError, e.message
    end

    private

    def update_provisioning
      MAP::SignUp::Service.new.update_provisioning(icn:, first_name:, last_name:, mpi_gcids: joined_mpi_gcids)
    end

    def log_provisioner_error(error)
      Rails.logger.error("[TermsOfUse] [Provisioner] Error: #{error.message}", { icn: })
    end

    def joined_mpi_gcids
      mpi_gcids.join('|')
    end
  end
end
