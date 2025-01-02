# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require_relative 'names'

module Organizations
  class Update
    include Sidekiq::Job
    include SentryLogging

    def perform
      Organizations::Names.all.each do |org| # rubocop:disable Rails/FindEach
        record = Veteran::Service::Organization.find_by(poa: org[:poa])
        next unless record

        record.update(name: org[:name])

        # Update the record address here, use the same retry logic as in the Representatives::Update.
        # Make sure to modify the resuce block to log the correct message.
      rescue => e
        log_message_to_sentry("Error updating organization name for POA in Organizations::UpdateNames: #{e.message}. POA: '#{org[:poa]}', Org Name: '#{org[:name]}'.") # rubocop:disable Layout/LineLength
        next
      end
    end
  end
end
