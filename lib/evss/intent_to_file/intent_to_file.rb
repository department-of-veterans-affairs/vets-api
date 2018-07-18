# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module IntentToFile
    class IntentToFile < Common::Base
      # The spelling of these status types has been validated with the partner team
      STATUS_TYPES = %w[
        active
        claim_recieved
        duplicate
        expired
        incomplete
      ].freeze

      attribute :id, String
      attribute :creation_date, DateTime
      attribute :expiration_date, DateTime
      attribute :participant_id, Integer
      attribute :source, String
      attribute :status, String
      attribute :type, String

      def initialize(args)
        raise ArgumentError, "invalid status type: #{args['status']}" unless STATUS_TYPES.include? args['status']
        super(args)
      end

      def expires_within_one_day?
        current = Time.current
        one_day_from_current = current + 1.day
        (current..one_day_from_current).cover? expiration_date
      end
    end
  end
end
