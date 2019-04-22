# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module GiBillStatus
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
    class Enrollment < Common::Base
      attribute :begin_date, DateTime
      attribute :end_date, DateTime
      attribute :facility_code, String
      attribute :facility_name, String
      attribute :participant_id
      attribute :training_type
      attribute :term_id
      attribute :hour_type
      attribute :full_time_hours, Integer
      attribute :full_time_credit_hour_under_grad, Integer
      attribute :vacation_day_count, Integer
      attribute :on_campus_hours, Float
      attribute :online_hours, Float
      attribute :yellow_ribbon_amount, Float
      attribute :status, String
      attribute :amendments, Array[Amendment]
    end
  end
end
