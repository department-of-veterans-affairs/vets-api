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

    MCP_NOTIFICATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.vha_new_copay_statement_email
    STATSD_KEY_PREFIX = 'api.copay_notifications.new_statement'

    def perform(statement)
      StatsD.increment("#{STATSD_KEY_PREFIX}.total")
      mpi_response = get_mpi_profile(identifier: statement['veteranIdentifier'],
                                     identifier_type: statement['identifierType'],
                                     facility_id: statement['facilityNum'])

      if mpi_response.ok?
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.success")
        create_notification_email_job(vet360_id: mpi_response.profile.vet360_id, icn: mpi_response.profile.icn)
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.failure")
        raise mpi_response.error
      end
    end

    def create_notification_email_job(vet360_id:, icn:)
      if vet360_id
        CopayNotifications::McpNotificationEmailJob.perform_async(vet360_id,
                                                                  MCP_NOTIFICATION_TEMPLATE)
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.mpi.vet360_not_found")
        log_exception_to_sentry(CopayNotifications::Vet360IdNotFound.new(icn), {},
                                { error: :new_statement_notification_job_error })
      end
    end

    def get_mpi_profile(identifier:, identifier_type:, facility_id:)
      if identifier_type == 'edipi'
        StatsD.increment("#{STATSD_KEY_PREFIX}.edipi")
        MPI::Service.new.find_profile_by_edipi(edipi: identifier)
      else
        StatsD.increment("#{STATSD_KEY_PREFIX}.vista")
        MPI::Service.new.find_profile_by_facility(
          facility_id:,
          vista_id: identifier
        )
      end
    end
  end
end
