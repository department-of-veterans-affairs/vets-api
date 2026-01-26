# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'
require_relative 'names'

module Organizations
  class UpdateNames
    include Sidekiq::Job
    include Vets::SharedLogging

    def perform
      Organizations::Names.all.each do |org| # rubocop:disable Rails/FindEach
        record = Veteran::Service::Organization.find_by(poa: org[:poa])
        next unless record

        record.update(name: org[:name])
      rescue => e
        error_message = 'Error updating organization name for POA in Organizations::UpdateNames: ' \
                        "#{e.message}. POA: '#{org[:poa]}', Org Name: '#{org[:name]}'."
        log_message_to_sentry(error_message)
        next
      end
    end
  end
end
