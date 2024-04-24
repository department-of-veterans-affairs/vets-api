# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require_relative 'names'
require_relative 'addresses'

module Organizations
  class UpdateNames
    include Sidekiq::Job
    include SentryLogging

    def perform
      Organizations::Names.all.each do |org| # rubocop:disable Rails/FindEach
        record = Veteran::Service::Organization.find_by(poa: org[:poa])
        next unless record

        record.update(name: org[:name])
      rescue => e
        log_message_to_sentry("Error updating organization name for POA in Organizations::UpdateNames: #{e.message}. POA: '#{org[:poa]}', Org Name: '#{org[:name]}'.") # rubocop:disable Layout/LineLength
        next
      end

      Organizations::Addresses.all.each do |org| # rubocop:disable Rails/FindEach
        record = Veteran::Service::Organization.find_by(poa: org[:poa])
        next unless record

        record.update(address_line1: org[:address_line1], address_line2: org[:address_line2],
                      address_line3: org[:address_line3], city: org[:city], state_code: org[:state_code], zip_code: org[:zip_code], zip_suffix: org[:zip_suffix]) # rubocop:disable Layout/LineLength
      rescue => e
        log_message_to_sentry("Error updating organization address for POA in Organizations::UpdateNames: #{e.message}. POA: '#{org[:poa]}'.") # rubocop:disable Layout/LineLength
      end
    end
  end
end
