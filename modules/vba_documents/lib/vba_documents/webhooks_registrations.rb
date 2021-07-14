# frozen_string_literal: true

require_dependency './lib/webhooks/utilities'

module VBADocuments
  module Registrations
    include Webhooks::Utilities

    register_events('gov.va.developer.benefits-intake.status_change',
                    api_name: 'PLAY_API') do |last_time_async_scheduled|
      next_run = if last_time_async_scheduled.nil?
                   0.seconds.from_now
                 else
                   30.seconds.from_now
                 end
      next_run
    rescue
      30.seconds.from_now
    end
  end
end
