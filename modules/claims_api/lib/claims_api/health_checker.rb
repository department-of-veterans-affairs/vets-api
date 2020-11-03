# frozen_string_literal: true

require 'bgs/service'
require 'mvi/service'
require 'evss/service'

module ClaimsApi
  class HealthChecker
    SERVICES = %w[evss mpi bgs vbms].freeze
    BGS_WSDL = "#{Settings.bgs.url}/VetRecordServiceBean/VetRecordWebService?WSDL"

    def initialize
      @evss_healthy = nil
      @mpi_healthy = nil
      @bgs_healthy = nil
      @vbms_healthy = nil
    end

    def services_are_healthy?
      # TODO: we should add check for Okta and SAML Proxies being up as well
      mpi_is_healthy? && evss_is_healthy? && bgs_is_healthy? && vbms_is_healthy?
    end

    def healthy_service?(service)
      case service
      when /evss/i
        evss_is_healthy?
      when /mpi/i
        mpi_is_healthy?
      when /bgs/i
        bgs_is_healthy?
      when /vbms/i
        vbms_is_healthy?
      else
        raise "ClaimsApi::HealthChecker doesn't recognize #{service}"
      end
    end

    private

    def evss_is_healthy?
      @evss_healthy = Settings.evss.mock_claims || EVSS::Service.service_is_up?
    end

    def mpi_is_healthy?
      @mpi_healthy = Settings.mvi.mock || MVI::Service.service_is_up?
    end

    def bgs_is_healthy?
      service = BGS::Services.new(
        external_uid: 'healthcheck_uid',
        external_key: 'healthcheck_key'
      )
      @bgs_healthy = service.vet_record.healthy?
    end

    def vbms_is_healthy?
      response = Faraday.get(Settings.vbms.url)
      @vbms_healthy = response.status == 200
    end
  end
end
