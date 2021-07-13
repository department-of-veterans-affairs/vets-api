require_dependency './lib/webhooks/utilities'

module VBADocuments
  module Registerations
    include Webhooks::Utilities

    register_events("gov.va.developer.benefits-intake.status_change",
                    "gov.va.developer.benefits-intake.status_change2", api_name: "PLAY_API") do |last_time_async_scheduled|
      #todo get rid of number two above
      next_run = nil
      if last_time_async_scheduled.nil?
        next_run = 0.seconds.from_now
      else
        next_run = 30.seconds.from_now
      end
      next_run
    rescue
      30.seconds.from_now
    end
  end
end
