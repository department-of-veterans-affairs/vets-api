# frozen_string_literal: true

require 'emis/military_information_service'
require 'emis/responses/get_military_service_episodes_response'

module EMISRedis
  # EMIS military information redis cached model
  class MilitaryInformation < Model
    # Class name of Service object used to fetch the data
    CLASS_NAME = 'MilitaryInformationService'

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
      hca_last_service_branch                      # done by the 1010 team
      last_service_branch
      currently_active_duty
      currently_active_duty_hash
      tours_of_duty                                # Started by TT1
      last_entry_date                              # done by the 1010 team
      last_discharge_date                          # done by the 1010 team
      is_va_service_connected
      post_nov111998_combat                        # done by the 1010 team
      sw_asia_combat                               # done by the 1010 team
      compensable_va_service_connected
      discharge_type                               # done by the 1010 team
      service_branches                             # started by TT1
      va_compensation_type
      service_periods
      guard_reserve_service_history
      latest_guard_reserve_service_period
    ].freeze  # map all of these to VAProfile.

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

    # In https://github.com/department-of-veterans-affairs/va.gov-team/issues/41046
    # we updated the military service branches to use an updated list from
    # Lighthouse BRD. The list below combines the branches from the former list
    # that was in the previous vets_json_schema, and the new list, from BRD. In
    # the future, we may consider udpating this constant to a dynamic value
    # populated by a call to Lighthouse BRD, but that is not necessary now.
    EVSS_COMBINED_SERVICE_BRANCHES = [
      'Army Air Corps or Army Air Force',
      'Air Force Academy',
      'Air Force',
      'Air Force Reserve',
      'Air Force Reserves',
      'Air National Guard',
      'Army Reserve',
      'Army Reserves',
      'Army',
      'Army National Guard',
      'Coast Guard Academy',
      'Coast Guard',
      'Coast Guard Reserve',
      'Coast Guard Reserves',
      'Marine Corps',
      'Marine Corps Reserve',
      'Marine Corps Reserves',
      'Merchant Marine',
      'Naval Academy',
      'Navy',
      'National Oceanic & Atmospheric Administration',
      'NOAA',
      'Navy Reserve',
      'Navy Reserves',
      'Other',
      'Public Health Service',
      'Space Force',
      'US Military Academy',
      "Women's Army Corps"
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
    def service_branch_used_in_disability(military_service_episode)
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

      service_name = "#{military_service_episode.branch_of_service} #{category}".strip
      service_name.gsub!('Air Force National Guard', 'Air National Guard')
      service_name if EVSS_COMBINED_SERVICE_BRANCHES.include? service_name
    end

    # @return [Array<Hash>] Data about the veteran's service periods
    #  including service branch served under and date range of each
    #  service period, used only for Form 526 - Disability form
    def service_periods
      service_episodes_by_date.map do |military_service_episode|
        service_branch = service_branch_used_in_disability(military_service_episode)
        return {} unless service_branch

        {
          service_branch:,
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

      DISCHARGE_TYPES[latest_service_episode&.discharge_character_of_service_code]
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

    # @return [Boolean] true if veteran is paid for a disability
    #  with a low disability percentage
    def compensable_va_service_connected
      disabilities.each do |disability|
        return true if disability.get_pay_amount.positive? &&
                       LOWER_DISABILITY_RATINGS.include?(disability.get_disability_percent)
      end

      false
    end

    # don't want to change this method name, it matches the attribute in the json schema
    # rubocop:disable Naming/PredicateName

    # @return [Boolean] true if veteran is paid for a disability
    #  with a high disability percentage
    def is_va_service_connected
      disabilities.each do |disability|
        pay_amount = disability.get_pay_amount
        disability_percent = disability.get_disability_percent

        return true if pay_amount.positive? && disability_percent >= HIGHER_DISABILITY_RATING
      end

      false
    end
    # rubocop:enable Naming/PredicateName

    # @return [String] If veteran is paid for a disability this method
    #  will return which type of disability it is
    #  (highDisability or lowDisability)
    def va_compensation_type
      # while supporting fallback support for the old fields,
      # make a consistent number of calls to the properties to
      # support specs that will be removed or updated
      high_disability = is_va_service_connected
      low_disability = compensable_va_service_connected

      if high_disability
        'highDisability'
      elsif low_disability
        'lowDisability'
      end
    end

    # @return [Array<EMIS::Models::Disability>] Cached array of the
    #  Veteran's disability data
    def disabilities
      @disabilities ||= items_from_response('get_disabilities')
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

    # @return [Array<EMIS::Models::GuardReserveServicePeriod>] Cached
    #  array of veteran's Guard and reserve service periods sorted
    #  by end date
    def guard_reserve_service_by_date
      @guard_reserve_service_by_date ||= guard_reserve_service_periods.sort_by do |per|
        per.end_date || Time.zone.today + 3650
      end.reverse
    end

    # @return [Array<Hash>] Veteran's guard and reserve service episode date
    #  ranges sorted by end_date
    def guard_reserve_service_history
      guard_reserve_service_by_date.map do |period|
        {
          from: period.begin_date,
          to: period.end_date
        }
      end
    end

    # @return [Hash] Cached array of veteran's Guard and reserve service
    # periods sorted by end date
    def latest_guard_reserve_service_period
      guard_reserve_service_history.try(:[], 0)
    end
  end
end
