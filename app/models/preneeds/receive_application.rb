# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Objects used to model pertinent data about a submitted {Preneeds::BurialForm} form.
  #
  # @!attribute tracking_number
  #   @return (see Preneeds::BurialForm#tracking_number)
  # @!attribute return_code
  #   @return [Integer] submission's return code - from EOAS
  # @!attribute application_uuid
  #   @return [String] submitted application's uuid - from EOAS
  # @!attribute return_description
  #   @return [String] submission's result - from EOAS
  # @!attribute submitted_at
  #   @return [Time] current time
  class ReceiveApplication < Common::Base
    attribute :tracking_number, String
    attribute :return_code, Integer
    attribute :application_uuid, String
    attribute :return_description, String
    attribute :submitted_at, Time, default: ->(_, __) { Time.zone.now }

    # Alias for #tracking_number
    #
    def receive_application_id
      tracking_number
    end
  end
end
