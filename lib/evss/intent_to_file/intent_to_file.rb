# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module IntentToFile
    class IntentToFile < Common::Base
      STATUS_TYPES = %w[
        expired
        active
      ].freeze

      attribute :id, String
      attribute :creation_date, DateTime
      attribute :expiration_date, DateTime
      attribute :participant_id, Integer
      attribute :source, String
      attribute :status, String
      attribute :type, String # Can only currently be "compensation"?

      def initialize(args)
        raise ArgumentError, "invalid status type: #{args['status']}" unless LETTER_TYPES.include? args['status']
        raise ArgumentError, "invalid type: #{args['type']}" unless args['status'] == 'compensation'
        super(args)
      end
    end
  end
end
