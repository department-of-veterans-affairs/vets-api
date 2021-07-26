# frozen_string_literal: true

module VBADocuments
  module Registrations
    include Webhooks::Utilities

    WEBHOOK_STATUS_CHANGE_EVENT = 'gov.va.developer.benefits-intake.status_change'

    register_events('gov.va.developer.benefits-intake.status_change',
                    api_name: 'PLAY_API', max_retries: 3) do |last_time_async_scheduled|
      next_run = if last_time_async_scheduled.nil?
                   0.seconds.from_now
                 else
                   30.seconds.from_now # TODO: make 15.minutes.from_now
                 end
      next_run
    rescue
      30.seconds.from_now
    end
  end
end
