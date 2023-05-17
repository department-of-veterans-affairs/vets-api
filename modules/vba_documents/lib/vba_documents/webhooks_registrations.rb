# frozen_string_literal: true

require 'webhooks/utilities'

module VBADocuments
  module Registrations
    include Webhooks::Utilities

    WEBHOOK_STATUS_CHANGE_EVENT = 'gov.va.developer.benefits-intake.status_change'

    register_events('gov.va.developer.benefits-intake.status_change',
                    api_name: 'vba_documents-v2',
                    max_retries: Settings.vba_documents.webhooks.registration_max_retries) do |ltas|
      next_run = if ltas.nil?
                   0.seconds.from_now
                 else
                   Settings.vba_documents.webhooks.registration_next_run_in_minutes.minutes.from_now
                 end
      next_run
    rescue
      15.minutes.from_now
    end
  end
end
