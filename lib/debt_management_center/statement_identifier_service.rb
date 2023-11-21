# frozen_string_literal: true

require 'mpi/service'

module DebtManagementCenter
  class StatementIdentifierService
    include SentryLogging
    STATSD_KEY_PREFIX = 'api.copay_notifications.new_statement'
    RETRYABLE_ERRORS = [
      Common::Exceptions::GatewayTimeout,
      Breakers::OutageException,
      Faraday::ConnectionFailed,
      Common::Exceptions::BackendServiceException
    ].freeze

    class MalformedMCPStatement < StandardError; end

    class RetryableError < StandardError
      def initialize(e)
        super(e.message)
      end
    end

    class Vet360IdNotFound < StandardError
      def initialize(icn)
        @icn = icn
        message = "MPIProfileMissingVet360Id: MPI Profile is missing vet360id #{@icn}"
        super(message)
      end
    end

    def initialize(statement)
      @statement = statement
      raise MalformedMCPStatement, statement unless legal_statement

      @identifier = @statement['veteranIdentifier']
      @identifier_type = @statement['identifierType']
      @facility_id = @statement['facilityNum']
      @identifier_key = nil
    end

    def get_icn
      mpi_response = get_mpi_profile
      if mpi_response.ok?
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.success")
        mpi_response.profile.icn
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.failure")
        raise mpi_response.error
      end
    rescue *RETRYABLE_ERRORS => e
      raise RetryableError, e
    end

    def vista_account_id
      offset = 16 - (@facility_id + @identifier).length
      padding = '0' * offset if offset >= 0
      "#{@facility_id}#{padding}#{@identifier}"
    end

    private

    def get_mpi_profile
      if @identifier_type == 'edipi'
        StatsD.increment("#{STATSD_KEY_PREFIX}.edipi")
        MPI::Service.new.find_profile_by_edipi(edipi: @identifier)
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.vista")
        MPI::Service.new.find_profile_by_facility(
          facility_id: @facility_id,
          vista_id: @identifier
        )
      end
    end

    def legal_statement
      @statement['veteranIdentifier'] &&
        @statement['identifierType'] &&
        @statement['facilityNum']
    end
  end
end
