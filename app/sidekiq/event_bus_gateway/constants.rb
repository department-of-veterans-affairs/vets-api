# frozen_string_literal: true

module EventBusGateway
  module Constants
    # VA Notify service settings
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools

    # The following retry counts each used to be 16, which was causing production strain and staging strain.
    # Controls the sidekiq (infrastructure level) retry when the letter ready email job fails.
    SIDEKIQ_RETRY_COUNT_FIRST_EMAIL = 5
    # Controls the sidekiq (infrastructure level) retry when the letter ready email retry job fails.
    SIDEKIQ_RETRY_COUNT_RETRY_EMAIL = 3
    # Controls the maximum number of email attempts to VA notify (application level).
    MAX_EMAIL_ATTEMPTS = 5

    # Controls the sidekiq (infrastructure level) retry when the letter ready sms job fails.
    SIDEKIQ_RETRY_COUNT_FIRST_SMS = 5

    # Controls the sidekiq (infrastructure level) retry when the letter ready push job fails.
    SIDEKIQ_RETRY_COUNT_FIRST_PUSH = 5

    # Controls the sidekiq (infrastructure level) retry when the letter ready notification job fails.
    SIDEKIQ_RETRY_COUNT_FIRST_NOTIFICATION = 5

    # Hostname mapping for different environments
    HOSTNAME_MAPPING = {
      'dev-api.va.gov' => 'dev.va.gov',
      'staging-api.va.gov' => 'staging.va.gov',
      'api.va.gov' => 'www.va.gov'
    }.freeze

    # DataDog tags for event bus gateway services
    DD_TAGS = [
      'service:event-bus-gateway',
      'team:cross-benefits-crew',
      'team:benefits',
      'itportfolio:benefits-delivery',
      'dependency:va-notify'
    ].freeze
  end
end
