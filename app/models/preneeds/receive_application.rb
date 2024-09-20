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
  class ReceiveApplication < Preneeds::Base

    attr_accessor :tracking_number,
                  :return_code,
                  :application_uuid,
                  :return_description,
                  :submitted_at

    def initialize(attributes = {})
      super
      @return_code = attributes[:return_code].to_i
      @submitted_at ||= current_time
    end

    # Alias for #tracking_number
    #
    def receive_application_id
      tracking_number
    end

    # @return [Time] current time
    #
    def current_time
      Time.zone.now
    end
  end
end
