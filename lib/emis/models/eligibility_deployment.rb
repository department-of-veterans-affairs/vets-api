# frozen_string_literal: true

require_relative 'eligibility_deployment_location'

module EMIS
  module Models
    # EMIS Eligibility Deployment data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each deployment
    #     record.
    # @!attribute begin_date
    #   @return [Date] date on which a Service member's deployment began. This is a generated
    #     field. It is the date of the first location event in a series of location events in
    #     which the amount of time between events is 21 days or less. However, for the Navy
    #     these events must also be of 14 days or greater in length. Example for the Navy: A
    #     member deploys for 7 days and then deploys three days later for 15 days, then this
    #     would create two separate deployment dates. However, if both deployments lasted 15
    #     days, then it would be considered one long deployment.
    # @!attribute end_date
    #   @return [Date] date on which a Service member's deployment ended. This is a generated
    #     field. It is the date of the final location event in a series of location events in
    #     which the amount of time between events is 21 days or less. However, for the Navy
    #     these events must also be of 14 days or greater in length. Example for the Navy: A
    #     member deploys for 7 days and then deploys three days later for 15 days, then this
    #     would create two separate deployment dates. However, if both deployments lasted 15
    #     days, then it would be considered one long deployment.
    # @!attribute project_code
    #   (see EMIS::Models::Deployment#project_code)
    # @!attribute locations
    #   @return [Array<EligibilityDeploymentLocation>] locations of the deployments.
    class EligibilityDeployment
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :project_code, String
      attribute :locations, Array[EligibilityDeploymentLocation]
    end
  end
end
