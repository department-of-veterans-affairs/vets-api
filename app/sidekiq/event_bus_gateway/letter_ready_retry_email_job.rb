# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyRetryEmailJob
    include Sidekiq::Job

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    def perform(participant_id, template_id, personalisation, notification_id)
      # TODO: Implement retry logic
    end
  end
end
