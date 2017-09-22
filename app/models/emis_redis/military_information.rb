# frozen_string_literal: true
module EMISRedis
  class MilitaryInformation < Model
    CLASS_NAME = 'MilitaryInformationService'

    SERVICE_BRANCHES = {
      'F' => 'air force',
      'A' => 'army',
      'C' => 'coast guard',
      'M' => 'marine corps',
      'N' => 'navy',
      'O' => 'noaa',
      'H' => 'usphs'
    }.freeze

    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }.freeze

    PREFILL_METHODS = %i(
      last_service_branch
      currently_active_duty
      tours_of_duty
      last_entry_date
      last_discharge_date
      is_va_service_connected
      post_nov111998_combat
      sw_asia_combat
      compensable_va_service_connected
      discharge_type
    ).freeze

    LOWER_DISABILITY_RATINGS = [10, 20, 30, 40].freeze
    HIGHER_DISABILITY_RATING = 50

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
    ).freeze

    VIETNAM = 'VNM'
    VIETNAM_WAR_RANGE = Date.new(1962, 1, 9)..Date.new(1975, 5, 7)

    def currently_active_duty
      {
        yes: latest_service_episode.end_date.future?
      }
    end

    def tours_of_duty
      military_service_episodes.map do |military_service_episode|
        {
          service_branch: military_service_episode.branch_of_service,
          date_range: {
            from: military_service_episode.begin_date.to_s,
            to: military_service_episode.end_date.to_s
          }
        }
      end
    end

    def last_service_branch
      return if latest_service_episode.blank?
      latest_service_episode.hca_branch_of_service
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
        return true if disability.pay_amount.positive? &&
                       LOWER_DISABILITY_RATINGS.include?(disability.disability_percent)
      end

      false
    end

    # don't want to change this method name, it matches the attribute in the json schema
    # rubocop:disable Style/PredicateName
    def is_va_service_connected
      disabilities.each do |disability|
        return true if disability.pay_amount.positive? && disability.disability_percent >= HIGHER_DISABILITY_RATING
      end

      false
    end
    # rubocop:enable Style/PredicateName

    def disabilities
      @disabilities ||= items_from_response('get_disabilities')
    end

    def military_service_episodes
      @military_service_episodes ||= items_from_response('get_military_service_episodes')
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= lambda do
        military_service_episodes.sort_by(&:end_date).reverse
      end.call
    end
  end
end
