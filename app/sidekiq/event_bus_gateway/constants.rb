# frozen_string_literal: true

module EventBusGateway
  module Constants
    # VA Notify service settings
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools

    # Sets the max retry count for each job, also the max retry count between both jobs.
    LETTER_READY_MAX_RETRY_COUNT = NOTIFY_SETTINGS&.letter_ready_email_job_retry_count&.to_i || 16

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

    # Retry for 2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    SIDEKIQ_RETRY_OPTIONS = {
      retry: LETTER_READY_MAX_RETRY_COUNT
    }.freeze

    MAX_EMAIL_ATTEMPTS = LETTER_READY_MAX_RETRY_COUNT
  end
end
