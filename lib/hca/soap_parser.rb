# frozen_string_literal: true

module HCA
  class SOAPParser < Common::Client::Middleware::Response::SOAPParser
    include SentryLogging

    class ValidationError < StandardError
    end

    VALIDATION_FAIL_KEY = 'api.hca.validation_fail'

    def on_complete(env)
      super
    rescue Common::Client::Errors::HTTPError => e
      doc = parse_doc(env.body)
      el = doc.locate('S:Envelope/S:Body/ns0:Fault/faultstring')[0]

      if el&.nodes.try(:[], 0) == 'formSubmissionException'
        StatsD.increment(VALIDATION_FAIL_KEY)
        Raven.tags_context(validation: 'hca')
        log_exception_to_sentry(e)

        raise ValidationError, 'HCA validation error'
      end

      raise
    end
  end
end
