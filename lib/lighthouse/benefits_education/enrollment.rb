# frozen_string_literal: true

require 'vets/model'
require 'lighthouse/benefits_education/amendment'

module BenefitsEducation
  ##
  # Model for a user's enrollment
  #
  # @!attribute begin_date
  #   @return [DateTime] The date the user enrolled
  # @!attribute end_date
  #   @return [DateTime] The date the user's enrollment ended
  # @!attribute facility_code
  #   @return [String] VA training facility code
  # @!attribute facility_name
  #   @return [String] The name of the institution where the user is enrolled
  # @!attribute participant_id
  #   @return [String] The user's ID as a participant of the institution
  # @!attribute training_type
  #   @return [String] The type of training the user received
  # @!attribute term_id
  #   @return [String] The term ID
  # @!attribute hour_type
  #   @return [String] The type of credit hours, i.e. "Residence" or "Distance"
  # @!attribute full_time_hours
  #   @return [Integer] The number of hours the user was a full-time student
  # @!attribute full_time_credit_hour_under_grad
  #   @return [Integer] The number of full-time undergrad credit hours for the user
  # @!attribute vacation_day_count
  #   @return [Integer] The number of vacation days the user logged
  # @!attribute on_campus_hours
  #   @return [Float] The number of credit hours the user was on campus
  # @!attribute online_hours
  #   @return [Float] The number of credit hours the user took online
  # @!attribute yellow_ribbon_amount
  #   @return [Float] The institution's financial contributions to the Yellow Ribbon Program
  # @!attribute status
  #   @return [String] The enrollment status
  # @!attribute amendments
  #   @return [Array[Amendment]] Any amendments made to this enrollment
  class Enrollment
    include Vets::Model

    attribute :begin_date, DateTime
    attribute :end_date, DateTime
    attribute :facility_code, String
    attribute :facility_name, String
    attribute :participant_id, Integer
    attribute :training_type, String
    attribute :term_id, String
    attribute :hour_type, String
    attribute :full_time_hours, Integer
    attribute :full_time_credit_hour_under_grad, Integer
    attribute :vacation_day_count, Integer
    attribute :on_campus_hours, Float
    attribute :online_hours, Float
    attribute :yellow_ribbon_amount, Float
    attribute :status, String
    attribute :amendments, Amendment, array: true

    def initialize(attributes)
      key_mapping = { 'begin_date_time' => 'begin_date', 'end_date_time' => 'end_date' }
      attributes.transform_keys! { |key| key_mapping[key] || key }
      super(attributes)
    end
  end
end
