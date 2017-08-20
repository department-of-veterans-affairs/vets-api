# frozen_string_literal: true
module EMISRedis
  class MilitaryInformation < Model
    CLASS_NAME = 'MilitaryInformationService'

    SERVICE_BRANCHES = {
      'F' => "air force",
      'A' => 'army',
      'C' => 'coast guard',
      'M' => "marine corps",
      'N' => 'navy',
      'O' => 'noaa',
      'H' => 'usphs'
    }

    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }

    LOWER_DISABILITY_RATINGS = [10, 20, 30, 40]

    NOV_1998 = Date.new(1998, 11, 11)
    GULF_WAR_RANGE = Date.new(1990, 8, 2)..NOV_1998

    SOUTHWEST_ASIA = %w(
      ARM
      AZE
      BHR
      CYP
      GEO
      IRQ
      ISR
      JOR
      KWT
      LBN
      OMN
      QAT
      SAU
      SYR
      TUR
      ARE
      YEM
    )

    VIETNAM = 'VNM'
    VIETNAM_WAR_RANGE = Date.new(1962, 1, 9)..Date.new(1975, 5, 7)

    def last_branch_of_service
      return if latest_service_episode.blank?

      SERVICE_BRANCHES[latest_service_episode.branch_of_service_code] || 'other'
    end

    def discharge_type
      return if latest_service_episode.blank?

      DISCHARGE_TYPES[latest_service_episode&.discharge_character_of_service_code] || 'other'
    end

    def post_nov111998_combat
      deployments.each do |deployment|
        return true if deployment.end_date > NOV_1998
      end

      false
    end

    def vietnam_service
      deployed_to?([VIETNAM], VIETNAM_WAR_RANGE)
    end

    def deployed_to?(countries, date_range)
      deployments.each do |deployment|
        deployment.locations.each do |location|
          return true if countries.include?(location.iso_alpha3_country) && date_range.overlaps?(location.date_range)
        end
      end

      false
    end

    def sw_asia_combat
      deployed_to?(SOUTHWEST_ASIA, GULF_WAR_RANGE)
    end

    def last_entry_date
      latest_service_episode&.begin_date&.to_s
    end

    def latest_service_episode
      service_episodes_by_date.try(:[], 0)
    end

    def last_discharge_date
      latest_service_episode&.end_date&.to_s
    end

    def deployments
      @deployments ||= items_from_response('get_deployment')
    end

    def compensable_va_service_connected
      disabilities.each do |disability|
        return true if disability.pay_amount > 0 && LOWER_DISABILITY_RATINGS.include?(disability.disability_percent)
      end

      false
    end

    def disabilities
      @disabilities ||= items_from_response('get_disabilities')
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= lambda do
        service_episodes = items_from_response('get_military_service_episodes')
        service_episodes.sort_by do |service_episode|
          service_episode.end_date
        end.reverse
      end.call
    end
  end
end

