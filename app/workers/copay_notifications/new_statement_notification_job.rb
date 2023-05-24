# frozen_string_literal: true

require 'mpi/service'

module CopayNotifications
  class Vet360IdNotFound < StandardError
    def initialize(icn)
      @icn = icn
      message = "MPIProfileMissingVet360Id: MPI Profile is missing vet360id #{@icn}"
      super(message)
    end
  end

  class NewStatementNotificationJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    MCP_NOTIFICATION_TEMPLATE = ''

    def perform(statement)
      mpi_response = if statement['identifierType'] == 'edipi'
                       MPI::Service.new.find_profile_by_edipi(edipi: statement['identifier'])
                     else
                       MPI::Service.new.find_profile_by_facility(
                         facility_id: statement['facilityNum'],
                         vista_id: statement['identifier']
                       )
                     end

      if mpi_response.ok?
        if mpi_response.profile.vet360_id
          CopayNotifications::McpNotificationEmailJob.perform_async(mpi_response.profile.vet360_id,
                                                                    MCP_NOTIFICATION_TEMPLATE)
        else
          log_exception_to_sentry(CopayNotifications::Vet360IdNotFound.new(mpi_response.profile.icn), {},
                                  { error: :new_statement_notification_job_error })
        end
      else
        raise mpi_response.error
      end
    end
  end
end
