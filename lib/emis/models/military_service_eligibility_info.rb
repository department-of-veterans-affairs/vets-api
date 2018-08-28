# frozen_string_literal: true

require 'emis/models/combat_pay'
require 'emis/models/deployment'
require 'emis/models/veteran_status'

module EMIS
  module Models
    class DentalIndicator
      include Virtus.model

      attribute :separation_date, Date
      attribute :dental_indicator, String
    end

    class EligibilityDeploymentLocation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :country_code, String
      attribute :iso_a3_country_code, String
    end

    class EligibilityDeployment
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :project_code, String
      attribute :locations, Array[EligibilityDeploymentLocation]
    end

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

    class MilitaryServiceEligibilityInfo
      include Virtus.model

      attribute :veteran_status, Array[EMIS::Models::VeteranStatus]
      attribute :dental_indicator, Array[DentalIndicator]
      attribute :military_service_episodes, Array[EligibilityMilitaryServiceEpisode]
    end
  end
end
