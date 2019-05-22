# frozen_string_literal: true

require 'emis/models/combat_pay'
require 'emis/models/deployment'
require 'emis/models/veteran_status'

module EMIS
  module Models
    # EMIS Dental Indicator data
    #
    # @!attribute separation_date
    #   @return [Date] date on which a member separated from a specific service and component.
    #     The data is received daily from DD 214 data feeds. The data is required under the
    #     iEHR program and electronic DD214 initiative. It will be made optionally available
    #     to customers requiring this element as part of a DD214 electronic inquiry.
    # @!attribute dental_indicator
    #   @return [String] This data element indicates whether the member was provided a
    #     complete dental examination and all appropriate dental services and treatment within
    #     90 days prior to separating from Active Duty. The data is received daily from DD 214
    #     data feeds. This field is Box 17 on DD Form 214, Aug 2009 version. The data is
    #     required under the iEHR program and electronic DD214 initiative. It will be made
    #     optionally available to customers requiring this element as part of a DD214
    #     electronic inquiry.
    #       N => No
    #       Y => Yes
    #       Z => Unknown
    class DentalIndicator
      include Virtus.model

      attribute :separation_date, Date
      attribute :dental_indicator, String
    end

    # EMIS Eligibility Deployment Location data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each deployment
    #     location record.
    # @!attribute country_code
    #   @return [String] ISO alpha2 country code that represents the country of the person’s
    #     location. The valid values also include dependencies and areas of special
    #     sovereignty.
    # @!attribute iso_a3_country_code
    #   @return [String] ISO alpha 3 code representing the country of deployment.
    class EligibilityDeploymentLocation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :country_code, String
      attribute :iso_a3_country_code, String
    end

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

    # EMIS Eligibility Military Service Episode data
    #
    # @!attribute begin_date
    #   @return [Date] date when a sponsor's personnel category and organizational
    #     affiliation began.
    # @!attribute end_date
    #   @return [Date] date when the personnel segment terminated.
    # @!attribute branch_of_service_code
    #   @return [String] date when the personnel segment terminated.

    class EligibilityMilitaryServiceEpisode
      include Virtus.model

      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :branch_of_service_code, String
      attribute :discharge_character_of_service_code, String
      attribute :honorable_discharge_for_va_purpose_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :deployments, Array[EligibilityDeployment]
      attribute :combat_pay, Array[EMIS::Models::CombatPay]
    end

    # Military service eligibility data
    class MilitaryServiceEligibilityInfo
      include Virtus.model

      attribute :veteran_status, Array[EMIS::Models::VeteranStatus]
      attribute :dental_indicator, Array[DentalIndicator]
      attribute :military_service_episodes, Array[EligibilityMilitaryServiceEpisode]
    end
  end
end
