# frozen_string_literal: true

require 'common/models/base'

module BenefitsEducation
  ##
  # Model for an amendment made to a user's enrollment
  #
  # @!attribute on_campus_hours
  #   @return [Float] The number of credit hours the user was on campus
  # @!attribute online_hours
  #   @return [Float] The number of credit hours the user took online
  # @!attribute yellow_ribbon_amount
  #   @return [Float] The institution's financial contributions to the Yellow Ribbon Program
  # @!attribute type
  #   @return [String] The amendment type
  # @!attribute status
  #   @return [String] The enrollment status
  # @!attribute change_effective_date
  #   @return [String] The date the amendment takes effect
  #
  class Amendment < Common::Base
    attribute :on_campus_hours, Float
    attribute :online_hours, Float
    attribute :yellow_ribbon_amount, Float
    attribute :type, String
    attribute :status, String
    attribute :change_effective_date, String

    def initialize(attributes)
      # Amendment objects previously weren't being serialized because of mismatched keys
      key_mapping = { 'residence_hours' => 'on_campus_hours',
                      'distance_hours' => 'online_hours',
                      'amendment_type' => 'type',
                      'amendment_status' => 'status',
                      'amendment_effective_date' => 'change_effective_date' }
      attributes.transform_keys! { |key| key_mapping[key] || key }
      super(attributes)
    end
  end
end
