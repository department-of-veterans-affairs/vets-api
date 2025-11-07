# frozen_string_literal: true

module StampableLogging
  extend ActiveSupport::Concern

  private

  # Main method for logging missing stamp data
  # @param field_mappings [Hash] Hash of field_name => { value:, context: {} }
  # @param log_level [Symbol] Log level (:info, :warn, :error)
  def log_missing_stamp_data(field_mappings, log_level: :info)
    field_mappings.each do |field_name, field_data|
      next if field_data[:value].present?

      log_missing_field(field_name, field_data[:context] || {}, log_level:)
    end
  end

  # Log a single missing field
  # @param field_name [String] Name of the missing field
  # @param additional_context [Hash] Additional context for the log
  # @param log_level [Symbol] Log level
  def log_missing_field(field_name, additional_context = {}, log_level: :info)
    return unless logging_enabled?

    context = base_log_context.merge(additional_context).compact
    context_string = context.map { |k, v| "#{k}: #{v}" }.join('; ')

    message = "IVC ChampVA Forms - #{form_class_name} Missing stamp data for #{field_name}; #{context_string}"
    Rails.logger.public_send(log_level, message)
  end

  def base_log_context
    {
      uuid: @uuid,
      form_number: @data['form_number']
    }
  end

  def logging_enabled?
    # consider not checking for production environment since we're only logging field names, not any PII
    Flipper.enabled?(:champva_stamper_logging) # && Settings.vsp_environment != 'production'
  end

  def form_class_name
    self.class.name.demodulize
  end
end
