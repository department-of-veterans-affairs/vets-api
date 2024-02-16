# frozen_string_literal: true

require_relative 'dental_indicator'
require_relative 'eligibility_military_service_episode'

module EMIS
  module Models
    # EMIS Military service eligibility data
    #
    # @!attribute dental_indicator
    #   @return [Array<EMIS::Models::DentalIndicator>] associated dental indicator data
    # @!attribute military_service_episodes
    #   @return [Array<EMIS::Models::EligibilityMilitaryServiceEpisode>] associated
    #     eligibility military service episodes
    class MilitaryServiceEligibilityInfo
      include Virtus.model

      attribute :dental_indicator, Array[DentalIndicator]
      attribute :military_service_episodes, Array[EligibilityMilitaryServiceEpisode]
    end
  end
end
