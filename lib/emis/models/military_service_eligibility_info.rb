# frozen_string_literal: true

require_relative 'dental_indicator'
require_relative 'veteran_status'
require_relative 'eligibility_military_service_episode'

module EMIS
  module Models
    # EMIS Military service eligibility data
    #
    # @!attribute veteran_status
    #   @return [Array<EMIS::Models::VeteranStatus>] associated veteran status data
    # @!attribute dental_indicator
    #   @return [Array<EMIS::Models::DentalIndicator>] associated dental indicator data
    # @!attribute military_service_episodes
    #   @return [Array<EMIS::Models::EligibilityMilitaryServiceEpisode>] associated
    #     eligibility military service episodes
    class MilitaryServiceEligibilityInfo
      include Virtus.model

      attribute :veteran_status, Array[EMIS::Models::VeteranStatus]
      attribute :dental_indicator, Array[DentalIndicator]
      attribute :military_service_episodes, Array[EligibilityMilitaryServiceEpisode]
    end
  end
end
