# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'
require 'va_profile/models/v3/validation_address'
require 'va_profile/v3/address_validation/service'
require_relative 'names'

module Organizations
  class Update
    include Sidekiq::Job
    include SentryLogging

    def perform
      Organizations::Names.all.each do |org| # rubocop:disable Rails/FindEach
        record = Veteran::Service::Organization.find_by(poa: org[:poa])
        next unless record

        process_org_data(record)
      rescue => e
        log_message_to_sentry("Error updating organization for POA in Organizations::Updates: #{e.message}. POA: '#{org[:poa]}', Org Name: '#{org[:name]}'.") # rubocop:disable Layout/LineLength
        next
      end
    end

    private

    def process_org_data(record)
      record.update(name: org[:name])
      # Update the record address here, use the same retry logic as in the Representatives::Update.
      # The rescue block should log the error and continue to the next record.
      # The rep address logic checks a passed in data object to see if the address needs to be updated,
      # is this necessary for the orgs since the total number of them is so much lower?
    end
  end
end
