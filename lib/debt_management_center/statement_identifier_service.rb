# frozen_string_literal: true

require 'mpi/service'

module DebtManagementCenter
  class StatementIdentifierService
    include SentryLogging
    STATSD_KEY_PREFIX = 'api.copay_notifications.new_statement'

    class MalformedMCPStatement < StandardError; end
    class UnableToSourceEmailForStatement < StandardError; end

    class ProfileMissingEmail < StandardError
      def initialize(vet360_id)
        @vet360_id = vet360_id
        message = "ProfileMissingEmail: Unable to derive an email address from vet360 id: #{@vet360_id}"
        super(message)
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

    def derive_email_address
      email_address = if @identifier_type == 'edipi'
                        source_from_edipi
                      else
                        source_from_vista
                      end
      raise UnableToSourceEmailForStatement, @statement unless email_address

      email_address
    end

    def vista_account_id
      offset = 16 - (@facility_id + @identifier).length
      padding = '0' * offset if offset >= 0
      "#{@facility_id}#{padding}#{@identifier}"
    end

    private

    def source_from_edipi
      @identifier_key = edipi_key
      index = IdentifierIndex.find(@identifier_key)
      return index.email_address if index

      credential_email = edipi_email_address(@identifier)
      if credential_email
        save_to_identifier(@identifier_key, credential_email)
        return credential_email
      end
      source_from_mpi
    end

    def source_from_vista
      @identifier_key = vista_key
      index = IdentifierIndex.find(vista_key)
      return index.email_address if index

      source_from_mpi
    end

    def source_from_mpi
      mpi_response = get_mpi_profile
      if mpi_response.ok?
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.success")
        icn_email = icn_email_address(mpi_response.profile.icn)
        if icn_email
          save_to_identifier(@identifier_key, icn_email)
          return icn_email
        end
        vet360_id = mpi_response&.profile&.vet360_id
        if vet360_id.nil?
          StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.vet360_not_found")
          log_exception_to_sentry(Vet360IdNotFound.new(mpi_response.profile.icn), {},
                                  { warning: :new_statement_notification_job_error })
        else
          source_from_vet360(vet360_id)
        end
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.failure")
        raise mpi_response.error
      end
    end

    def source_from_vet360(vet360_id)
      person_resp = VAProfile::ContactInformation::Service.get_person(vet360_id)
      vet360_email = person_resp.person&.emails&.first&.email_address
      if vet360_email
        StatsD.increment('api.copay_notifications.new_statement.vet_360.success')
        save_to_identifier(@identifier_key, vet360_email)
        vet360_email
      else
        StatsD.increment('api.copay_notifications.new_statement.vet_360.failure')
        log_exception_to_sentry(
          ProfileMissingEmail.new(vet360_id),
          {}, {},
          :warning
        )
      end
    end

    def edipi_email_address(edipi)
      verification = UserVerification.find_by(dslogon_uuid: edipi)
      verification&.user_credential_email&.credential_email
    end

    def icn_email_address(icn)
      account = UserAccount.find_by(icn:)
      return nil unless account

      addresses = account.user_verifications.map do |verification|
        verification&.user_credential_email&.credential_email
      end
      begin
        addresses.first
      rescue
        nil
      end
    end

    def save_to_identifier(identifier, email)
      IdentifierIndex.create(identifier:, email_address: email)
    end

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

    def edipi_key
      "edipi:#{@identifier}"
    end

    def vista_key
      "vista_account_id:#{vista_account_id}"
    end

    def legal_statement
      @statement['veteranIdentifier'] &&
        @statement['identifierType'] &&
        @statement['facilityNum']
    end
  end
end
