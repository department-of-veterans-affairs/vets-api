# frozen_string_literal: true

module MebApi
  # Service object for building structured error log parameters
  # for confirmation email failures
  class EmailErrorLogger
    attr_reader :error, :form_type, :form_tag

    def initialize(error:, form_type:, form_tag:)
      @error = error
      @form_type = form_type
      @form_tag = form_tag
    end

    def log_params(claim_status:, template_id:, email_present:, user_icn:)
      {
        form_type:,
        claim_status:,
        template_id:,
        email_present:,
        error_class: error.class.name,
        error_message:,
        icn: user_icn,
        http_status:,
        response_body:
      }.compact
    end

    private

    def error_message
      error.message.presence || 'No error message provided'
    end

    def http_status
      error.status if error.is_a?(Common::Client::Errors::ClientError)
    end

    def response_body
      return unless error.respond_to?(:body) && error.body.present?

      error.body.to_s.truncate(250)
    end
  end
end
