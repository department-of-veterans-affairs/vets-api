# frozen_string_literal: true

module HCA
  class SOAPParser < Common::Client::Middleware::Response::SOAPParser
    include SentryLogging

    class ValidationError < StandardError
    end

    VALIDATION_FAIL_KEY = 'api.hca.validation_fail'
    FAULT_EL = 'S:Envelope/S:Body/ns0:Fault'
    FAULT_STRING_EL = "#{FAULT_EL}/faultstring"
    FAULT_CODE_EL = "#{FAULT_EL}/detail/VoaFaultException/faultExceptions/faultException/code"

    def on_complete(env)
      super
    rescue Common::Client::Errors::HTTPError => e
      doc = parse_doc(env.body)
      el = doc.locate(FAULT_STRING_EL)[0]

      if el&.nodes.try(:[], 0) == 'formSubmissionException' &&
         doc.locate(FAULT_CODE_EL)[0]&.nodes.try(:[], 0) != 'VOA_0240'
        StatsD.increment(VALIDATION_FAIL_KEY)
        Raven.tags_context(validation: 'hca')
        log_exception_to_sentry(e)

        raise ValidationError, 'HCA validation error'
      end

      raise
    end
  end
end
