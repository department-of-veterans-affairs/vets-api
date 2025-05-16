# frozen_string_literal: true

require 'vets/model'
require_relative 'special_issue'

module EVSS
  module DisabilityCompensationForm
    # Model of an individual rated disability record. The VA assigns veterans disability ratings
    # based on the severity of their disabilities. This rating is used to determine their compensation rates.
    #
    # @!attribute decision_code
    #   @return [String] Code for the decision, e.g. ['NOTSVCCON', 'SVCCONNECTED']
    # @!attribute decision_text
    #   @return [String] Description of the decision, e.g. 'Service Connected'
    # @!attribute diagnostic_code
    #   @return [Integer] Diagnostic Code of each condition used to assign the disability rating
    # @!attribute name
    #   @return [String] We map 'attrs['diagnostic_text']' to {name} in order to match the same attribute in
    #     the submit endpoint
    # @!attribute effective_date
    #   @return [DateTime] The date the VA receives an application. Benefits start the first day of the following month.
    # @!attribute rated_disability_id
    #   @return [String] Zero-based incremented id for a veterans disability
    # @!attribute rating_decision_id
    #   @return [String] Relational id pointing the decision
    # @!attribute rating_percentage
    #   @return [Integer] For every disability claim, the VA assigns a severity rating ranging from 0-100%
    # @!attribute related_disability_date
    #   @return [DateTime] Report date of a related disability
    # @!attribute special_issues
    #   @return [Array<EVSS::DisabilityCompensationForm::SpecialIssue>] List of complicating issues
    #     e.g. ['POW', 'PTSD_1']
    #
    class RatedDisability
      include Vets::Model

      attribute :decision_code, String
      attribute :decision_text, String
      attribute :diagnostic_code, Integer
      attribute :name, String
      attribute :effective_date, DateTime
      attribute :rated_disability_id, String
      attribute :rating_decision_id, String
      attribute :rating_percentage, Integer
      attribute :related_disability_date, DateTime
      attribute :special_issues, EVSS::DisabilityCompensationForm::SpecialIssue, array: true, default: []

      def initialize(attrs)
        super(attrs.merge({name: attrs['diagnostic_text']}))
      end

      # @return [String] Shorthand for rated_disability_id
      #
      def id
        rated_disability_id
      end
    end
  end
end
