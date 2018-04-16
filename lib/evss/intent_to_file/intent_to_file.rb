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

      ITF_TYPE = %w[
        compensation
        pension
        survivor
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
        raise ArgumentError, "invalid type: #{args['type']}" unless ITF_TYPE.include? args['type']
        super(args)
      end
    end
  end
end
