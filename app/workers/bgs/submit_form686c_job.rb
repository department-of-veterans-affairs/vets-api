# frozen_string_literal: true

module BGS
  class SubmitForm686cJob
    include Sidekiq::Worker

    # we do individual service retries in lib/bgs/service.rb
    sidekiq_options retry: false

    def perform(user, payload)
      # This PR is blocked until others are ready
      # BGS::Form686c.new(user).submit(payload)
    end
  end
end