# frozen_string_literal: true

class EmailVerificationJob
  include Sidekiq::Job
  include Vets::SharedLogging
  sidekiq_options retry: 5 # exponential backoff, retries for ~17 mins

  STATS_KEY = 'api.vanotify.email_verification'

  sidekiq_retries_exhausted do |msg, _ex|
    job_id = msg['jid']
    job_class = msg['class']
    error_class = msg['error_class']
    error_message = msg['error_message']
    args = msg['args']

    template_type = args[0] if args&.length&.positive?
    message = "#{job_class} retries exhausted"

    Rails.logger.error(message, { job_id:, error_class:, error_message:, template_type: })
    StatsD.increment("#{STATS_KEY}.retries_exhausted")
  end

  # TODO: Add back email_address param when ready to send real emails
  def perform(template_type, _email_address, personalisation = {})
    return unless Flipper.enabled?(:auth_exp_email_verification_enabled)

    get_template_id(template_type)
    validate_personalisation!(template_type, personalisation)

    # TODO: Set up custom callback class
    # callback_options = {
    #   callback_klass: 'EmailVerificationCallback',
    #   callback_metadata: {
    #     statsd_tags: {
    #       service: 'vagov-profile-email-verification',
    #       function: "#{template_type}_email"
    #     }
    #   }
    # }

    Rails.logger.info('Email verification sent (logging only - not actually sent)', { template_type: })
    # TODO: Replace above log with actual VA Notify call:
    # notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key, callback_options)
    # notify_client.send_email(
    #   {
    #     email_address: email_address,
    #     template_id: template_id,
    #     personalisation: personalisation
    #   }.compact

    StatsD.increment("#{STATS_KEY}.success")
  rescue ArgumentError => e
    # Log application logic errors for debugging - these go to Sidekiq's Dead Job Queue (no retries)
    Rails.logger.error('EmailVerificationJob validation failed', { error: e.message, template_type: })
    raise e
  rescue => e
    # Log and count service/operational failures
    # Service failures get retried by Sidekiq (5xx errors), 400s don't retry
    Rails.logger.error('EmailVerificationJob failed', { error: e.message, template_type: })
    StatsD.increment("#{STATS_KEY}.failure")
    raise e
  end

  private

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
      validate_required_fields!(personalisation, %w[verification_link first_name email_address], template_type)
    when 'verification_success'
      validate_required_fields!(personalisation, %w[first_name], template_type)
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
