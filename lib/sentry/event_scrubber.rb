# frozen_string_literal: true

# Scrubber means either a filter or sanitizer.

require_relative 'scrubbers/email_sanitizer'
require_relative 'scrubbers/filter_request_body'
require_relative 'scrubbers/log_as_warning'
require_relative 'scrubbers/pii_sanitizer'

module Sentry
  class EventScrubber
    def initialize(event, _hint)
      @unclean_event = event
    end

    def cleaned_event
      event = @unclean_event
      scrubbers.each do |scrubber|
        event = scrub_with(event:, scrubber:)
      end
      event
    end

    # NOTE: Unsure if the order matters
    def scrubbers
      [email_sanitizer, pii_sanitizer, log_as_warning, filter_request_body]
    end

    private

    def scrub_with(event:, scrubber:)
      scrubber.process(event.to_hash)
    end

    def email_sanitizer
      Scrubbers::EmailSanitizer.new
    end

    def pii_sanitizer
      Scrubbers::PIISanitizer.new
    end

    def log_as_warning
      Scrubbers::LogAsWarning.new
    end

    def filter_request_body
      Scrubbers::FilterRequestBody.new
    end
  end
end
