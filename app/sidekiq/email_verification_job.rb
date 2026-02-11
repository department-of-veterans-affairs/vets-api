# frozen_string_literal: true

require 'sidekiq/attr_package'

class EmailVerificationJob
  include Sidekiq::Job
  include Vets::SharedLogging
  sidekiq_options retry: 5 # exponential backoff, retries for ~17 mins

  STATS_KEY = 'api.vanotify.email_verification'

  STATS_RETRIES_EXHAUSTED = "#{STATS_KEY}.retries_exhausted".freeze
  STATS_SUCCESS = "#{STATS_KEY}.success".freeze
  STATS_FAILURE = "#{STATS_KEY}.failure".freeze

  sidekiq_retries_exhausted do |msg, _ex|
    job_id = msg['jid']
    job_class = msg['class']
    error_class = msg['error_class']
    error_message = msg['error_message']
    args = msg['args']

    template_type = args[0] if args&.length&.positive?
    cache_key = args[1] if args&.length&.>(1)

    message = "#{job_class} retries exhausted"

    Rails.logger.error(message, { job_id:, error_class:, error_message:, template_type: })
    StatsD.increment(STATS_RETRIES_EXHAUSTED)

    Sidekiq::AttrPackage.delete(cache_key) if cache_key
  end

  # TODO: Add back email_address param when ready to send real emails
  # rubocop:disable Metrics/MethodLength
  def perform(template_type, cache_key)
    return unless Flipper.enabled?(:auth_exp_email_verification_enabled)

    # Retrieve PII data from Redis using the cache key
    personalisation_data = Sidekiq::AttrPackage.find(cache_key)

    unless personalisation_data
      Rails.logger.error('EmailVerificationJob failed: Missing personalisation data in Redis', {
                           template_type:,
                           cache_key_present: cache_key.present?
                         })
      raise ArgumentError, 'Missing personalisation data in Redis'
    end

    # Build personalisation hash based on template type and available data
    personalisation = build_personalisation(template_type, personalisation_data)

    validate_personalisation!(template_type, personalisation)

    Rails.logger.info('Email verification sent (logging only - not actually sent)', { template_type: })
    # TODO: Replace above log with actual VA Notify call:
    # notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key, callback_options(template_type))
    # notify_client.send_email(
    #   {
    #     email_address: personalisation_data[:email],
    #     template_id: get_template_id(template_type),
    #     personalisation:
    #   }.compact
    # )

    StatsD.increment(STATS_SUCCESS)
    Sidekiq::AttrPackage.delete(cache_key) if cache_key
  rescue ArgumentError => e
    # Log application logic errors for debugging - these go to Sidekiq's Dead Job Queue (no retries)
    Rails.logger.error('EmailVerificationJob validation failed', { error: e.message, template_type: })
    raise e
  rescue Sidekiq::AttrPackageError => e
    # Log AttrPackage errors as application logic errors (no retries)
    Rails.logger.error('EmailVerificationJob AttrPackage error', { error: e.message, template_type: })
    raise ArgumentError, e.message
  rescue => e
    # Log and count service/operational failures
    # Service failures get retried by Sidekiq (5xx errors), 400s don't retry
    Rails.logger.error('EmailVerificationJob failed', { error: e.message, template_type: })
    StatsD.increment(STATS_FAILURE)
    raise e
  end
  # rubocop:enable Metrics/MethodLength

  private

  def build_personalisation(template_type, personalisation_data)
    case template_type
    when 'initial_verification', 'annual_verification', 'email_change_verification'
      {
        'verification_link' => personalisation_data[:verification_link],
        'first_name' => personalisation_data[:first_name],
        'email_address' => personalisation_data[:email]
      }
    when 'verification_success'
      {
        'first_name' => personalisation_data[:first_name]
      }
    else
      raise ArgumentError, 'Unknown template type'
    end
  end

  def callback_options(template_type)
    {
      callback_klass: 'EmailVerificationCallback',
      callback_metadata: {
        statsd_tags: {
          service: 'vagov-profile-email-verification',
          function: "#{template_type}_email"
        }
      }
    }
  end

  def get_template_id(template_type)
    case template_type
    when 'initial_verification', 'annual_verification'
      Settings.vanotify.services.va_gov.template_id.contact_email_address_confirmation_needed_email
    when 'email_change_verification'
      Settings.vanotify.services.va_gov.template_id.contact_email_address_change_confirmation_needed_email
    when 'verification_success'
      Settings.vanotify.services.va_gov.template_id.contact_email_address_confirmed_email
    else
      raise ArgumentError, 'Unknown template type'
    end
  end

  def validate_personalisation!(template_type, personalisation)
    raise ArgumentError, 'Personalisation cannot be nil' if personalisation.nil?

    case template_type
    when 'initial_verification', 'annual_verification', 'email_change_verification'
      validate_required_fields!(personalisation, %w[verification_link first_name email_address])
    when 'verification_success'
      validate_required_fields!(personalisation, %w[first_name])
    else
      raise ArgumentError, 'Unknown template type'
    end
  end

  def validate_required_fields!(personalisation, required_fields)
    missing_fields = required_fields.select { |field| personalisation[field].blank? }

    unless missing_fields.empty?
      raise ArgumentError, "Missing required personalisation fields: #{missing_fields.join(', ')}"
    end
  end
end
