# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module IntentToFile
    ## TODO Remove this file
    # Model for an intent to file
    #
    # @param args [Hash] Data to include in the intent to file
    #
    # @!attribute id
    #   @return [String] Intent to file ID
    # @!attribute creation_date
    #   @return [DateTime] Date and time the intent to file was created
    # @!attribute expiration_date
    #   @return [DateTime] Date and time the intent to file will expire
    # @!attribute participant_id
    #   @return [Integer] The user's participant ID
    # @!attribute source
    #   @return [String] The intent to file source
    # @!attribute status
    #   @return [String] The intent to file status
    # @!attribute type
    #   @return [String] The intent to file type
    #
    class IntentToFile < Common::Base
      # The spelling of these status types has been validated with the partner team
      STATUS_TYPES = %w[
        active
        claim_recieved
        duplicate
        expired
        incomplete
        canceled
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

      ##
      # @return [Boolean] Does the intent to file expire within one day
      #
      def expires_within_one_day?
        current = Time.current
        one_day_from_current = current + 1.day
        (current..one_day_from_current).cover? expiration_date
      end
    end
  end
end
