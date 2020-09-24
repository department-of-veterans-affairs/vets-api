# frozen_string_literal: true

require_relative 'deployment_location'

module EMIS
  module Models
    # EMIS veteran deployments data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique
    #     key on each deployment location record
    # @!attribute begin_date
    #   @return [Date] the date on which a Service member's deployment began. This is a
    #     generated field. It is the date of the first location event in a series of location events
    #     in which the amount of time between events is 21 days or less. However, for the Navy
    #     these events must also be of 14 days or greater in length. Example for the Navy: A
    #     member deploys for 7 days and then deploys three days later for 15 days, then this
    #     would create two separate deployment dates. However, if both deployments lasted 15
    #     days, then it would be considered one long deployment.
    # @!attribute end_date
    #   @return [Date] the date on which a Service member's deployment ended. This is a
    #     generated field. It is the date of the final location event in a series of location events
    #     in which the amount of time between events is 21 days or less. However, for the Navy
    #     these events must also be of 14 days or greater in length. Example for the Navy: A
    #     member deploys for 7 days and then deploys three days later for 15 days, then this
    #     would create two separate deployment dates. However, if both deployments lasted 15
    #     days, then it would be considered one long deployment.
    # @!attribute project_code
    #   @return [String] this data element provides the granularity to differentiate between
    #     the various contingencies. Currently that granularity is not available, so it is
    #     defaulted to 9GF for OCO contingencies.
    #       3GC => Deepwater Horizon
    #       3JH => Mexico Wildland Firefighting
    #       3JO => Border Patrol (Jump Start)
    #       3JT => Unified Response
    #       9BU => Southern Watch/Desert Thunder
    #       9EC => Uphold Democracy
    #       9EV => Joint Endeavor/Guard
    #       9FF => Joint Forge
    #       9FS => Allied Force
    #       9FV => Joint Guardian
    #       9GF => Overseas Contingency Operation (OCO)
    #       9GY => Hurricane Katrina (Aug 31, 2005)
    #       9HA => Hurricane Ophelia (Wilma Sep 14, 2005)
    #       9HB => Hurricane Rita (Sep 21, 2005)
    #       9HC => Pakistan
    #       A20 => AD - ADT - IADT
    #       A21 => AD - ADT - AT
    #       A22 => AD - ADT - OTD
    #       A25 => AD - ADOT - ADOS
    #       A26 => AD - ADOT - AGR
    #       A27 => AD - ADOT - Involuntary
    #       A28 => AD - Other
    #       A99 => AD - Unknown (derived period)
    #       B21 => FTNG - AT
    #       B22 => FTNGD - OTD
    #       B25 => FTNGD - OS
    #       B26 => FTNGD - AGR
    #       B27 => FTNGD - Involuntary
    #       B99 => FTNGD - Unknown (derived period)
    # @!attribute termination_reason
    #   @return [String] the code that represents the reason that deployment segment was
    #     terminated.
    #       C => Completion of Deployment Period
    #       W => Not Applicable
    # @!attribute transaction_date
    #   @return [Date] the calendar date of the deployment.
    # @!attribute locations
    #   @return [Array<DeploymentLocation>] locations of the deployments.
    class Deployment
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :project_code, String
      attribute :termination_reason, String
      attribute :transaction_date, Date
      attribute :locations, Array[DeploymentLocation]
    end
  end
end
