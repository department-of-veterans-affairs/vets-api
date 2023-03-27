# frozen_string_literal: true

module EMISRedis
  # EMIS military information redis cached model
  class MilitaryInformationV2 < Model
    # Class name of Service object used to fetch the data
    CLASS_NAME = 'MilitaryInformationServiceV2'

    # Mapping of discharge type codes to discharge types
    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }.freeze

    # Mapping of discharge type codes to discharge types used in veteran
    # verification API
    EXTERNAL_DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'E' => 'other-than-honorable',
      'F' => 'dishonorable',
      'H' => 'honorable-absence-of-negative-report',
      'J' => 'honorable-for-va-purposes',
      'K' => 'dishonorable-for-va-purposes',
      'Y' => 'uncharacterized',
      'Z' => 'unknown'
    }.freeze

    # Data methods used to populate +FormMilitaryInformation+ prefill class
    PREFILL_METHODS = %i[
      hca_last_service_branch
      last_service_branch
      currently_active_duty
      currently_active_duty_hash
      tours_of_duty
      last_entry_date
      last_discharge_date
      post_nov111998_combat
      sw_asia_combat
      discharge_type
      service_branches
      service_periods
    ].freeze

    # Disability ratings counted as lower
    LOWER_DISABILITY_RATINGS = [10, 20, 30, 40].freeze
    # Disability ratings counted as higher
    HIGHER_DISABILITY_RATING = 50

    NOV_1998 = Date.new(1998, 11, 11)
    # Date range for the Gulf War
    GULF_WAR_RANGE = (Date.new(1990, 8, 2)..NOV_1998)

    # ISO Country codes for southwest Asia
    SOUTHWEST_ASIA = %w[
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
    ].freeze

    # Vietnam ISO country code
    VIETNAM = 'VNM'
    # Date range for Vietnam War
    VIETNAM_WAR_RANGE = (Date.new(1962, 1, 9)..Date.new(1975, 5, 7))

    # @return [Boolean] true if the user is currently
    #  serving in active duty
    def currently_active_duty
      currently_active_duty_hash[:yes]
    end

    # @return [Hash] currently active duty data in hash format
    def currently_active_duty_hash
      value =
        if latest_service_episode.present?
          end_date = latest_service_episode.end_date
          end_date.nil? || end_date.future?
        else
          false
        end

      {
        yes: value
      }
    end

    # @return [Array<Hash>] Data about the veteran's tours of duty
    #  including service branch served under and date range of each tour
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

    # Convert service branch code from a military service episode
    # into a formatted readable string.
    # EVSS requires the reserve/national guard category to be a part
    # of the service branch field.
    # @param military_service_episode [EMIS::Models::MilitaryServiceEpisode]
    #  Military service episode model
    # @return [String] Readable service branch name formatted for EVSS
    def build_service_branch(military_service_episode)
      branch = case military_service_episode.hca_branch_of_service
               when 'noaa'
                 military_service_episode.hca_branch_of_service.upcase
               when 'usphs'
                 'Public Health Service'
               else
                 military_service_episode.hca_branch_of_service.titleize
               end

      category = case military_service_episode.personnel_category_type_code
                 when 'A'
                   ''
                 when 'N'
                   'National Guard'
                 when 'V' || 'Q'
                   'Reserve'
                 else
                   ''
                 end

      "#{branch} #{category}".strip
    end

    def get_guard_personnel_category_type(guard_service_period)
      case guard_service_period.personnel_category_type_code
      when 'N'
        'National Guard'
      when 'V' || 'Q'
        'Reserve'
      else
        ''
      end
    end

    # @return [Array<Hash>] Data about the veteran's service periods
    #  including service branch served under and date range of each
    #  service period
    def service_periods
      service_episodes_by_date.map do |military_service_episode|
        # avoid prefilling if service branch is 'other' as this breaks validation
        return {} if military_service_episode.hca_branch_of_service == 'other'

        {
          service_branch: build_service_branch(military_service_episode),
          date_range: {
            from: military_service_episode.begin_date.to_s,
            to: military_service_episode.end_date.to_s
          }
        }
      end
    end

    # @return [Array<String>] Veteran's unique service branch codes
    def service_branches
      military_service_episodes.map(&:branch_of_service_code).uniq
    end

    # @return [String] Last service branch the veteran served under in
    #  readable format
    def last_service_branch
      latest_service_episode&.branch_of_service
    end

    # @return [String] Last service branch the veteran served under in
    #  HCA schema format
    def hca_last_service_branch
      latest_service_episode&.hca_branch_of_service
    end

    # @return [String] Discharge type from last service episode in readable
    #  format
    def discharge_type
      return if latest_service_episode.blank?

      DISCHARGE_TYPES[latest_service_episode&.discharge_character_of_service_code] || 'other'
    end

    # @return [Boolean] true if veteran served a tour of duty
    #  after November 1998
    def post_nov111998_combat
      deployments.each do |deployment|
        return true if deployment.end_date > NOV_1998
      end

      false
    end

    # @return [Boolean] true if veteran served in the Vietnam
    #  War
    def vietnam_service
      deployed_to?([VIETNAM], VIETNAM_WAR_RANGE)
    end

    # @param countries [Array<String>] Array of ISO3 country codes
    # @param date_range [Range] Date range
    # @return [Boolean] true if veteran was deployed to any of
    #  of the countries within the specified date range
    def deployed_to?(countries, date_range)
      deployments.each do |deployment|
        deployment.locations.each do |location|
          return true if countries.include?(location.iso_alpha3_country) && date_range.overlaps?(location.date_range)
        end
      end

      false
    end

    # @return [Boolean] true if the veteran served in southwest
    #  Asia during the Gulf war
    def sw_asia_combat
      deployed_to?(SOUTHWEST_ASIA, GULF_WAR_RANGE)
    end

    # @return [String] Date string of the last service episode's start
    #  date
    def last_entry_date
      latest_service_episode&.begin_date&.to_s
    end

    # @return [EMIS::Models::MilitaryServiceEpisode] Most recent military
    #  service episode
    def latest_service_episode
      service_episodes_by_date.try(:[], 0)
    end

    # @return [String] Date string of the last service episode's end
    #  date
    def last_discharge_date
      latest_service_episode&.end_date&.to_s
    end

    # @return [EMIS::Models::Deployment] Cached array of the
    #  Veteran's deployments
    def deployments
      @deployments ||= items_from_response('get_deployment')
    end

    # @return [Array<EMIS::Models::MilitaryServiceEpisode>] Cached
    #  array of veteran's military service episodes
    def military_service_episodes
      @military_service_episodes ||= items_from_response('get_military_service_episodes')
    end

    # @return [Array<EMIS::Models::MilitaryServiceEpisode>] Cached
    #  array of veteran's military service episodes sorted by end_date
    def service_episodes_by_date
      @service_episodes_by_date ||= lambda do
        military_service_episodes.sort_by { |ep| ep.end_date || Time.zone.today + 3650 }.reverse
      end.call
    end

    # @return [Array<EMIS::Models::MilitaryServiceEpisode>] Cached
    #  array of veteran's military service episodes sorted by begin_date
    def service_episodes_by_begin_date
      @service_episodes_by_date ||= lambda do
        military_service_episodes.sort_by { |ep| ep.begin_date || Time.zone.today + 3650 }
      end.call
    end

    # @return [Array<Hash>] Veteran's military service episodes sorted by date
    #  in hash format including data about branch of service, date range,
    #  and personnel category codes
    def service_history
      service_episodes_by_date.map do |episode|
        {
          branch_of_service: episode.branch_of_service,
          begin_date: episode.begin_date,
          end_date: episode.end_date,
          personnel_category_type_code: episode.personnel_category_type_code
        }
      end
    end

    # @return [Array<EMIS::Models::GuardReserveServicePeriod>] Cached
    #  array of veteran's Guard and reserve service periods
    def guard_reserve_service_periods
      @guard_reserve_service_periods ||= items_from_response('get_guard_reserve_service_periods')
    end
  end
end
