# frozen_string_literal: true

require 'va_profile/military_personnel/service'

module HCA
  class MilitaryInformation
    PREFILL_METHODS = %w[
      currently_active_duty
      currently_active_duty_hash
      discharge_type
      guard_reserve_service_history
      hca_last_service_branch
      last_discharge_date
      last_entry_date
      last_service_branch
      latest_guard_reserve_service_period
      post_nov111998_combat
      service_branches
      service_episodes_by_date
      service_periods
      sw_asia_combat
      tours_of_duty
    ].freeze

    HCA_SERVICE_BRANCHES = {
      'A' => 'army',
      'C' => 'coast guard',
      'F' => 'air force',
      'H' => 'usphs',
      'M' => 'marine corps',
      'N' => 'navy',
      'O' => 'noaa'
    }.freeze

    DISCHARGE_TYPES = {
      'A' => 'honorable',
      'B' => 'general',
      'D' => 'bad-conduct',
      'F' => 'dishonorable',
      'J' => 'honorable',
      'K' => 'dishonorable'
    }.freeze

    SOUTHWEST_ASIA = %w[
      AM
      AZ
      BH
      CY
      GE
      IQ
      IL
      JO
      KW
      LB
      OM
      QA
      SA
      SY
      TR
      AE
      YE
    ].freeze

    NOV_1998 = Date.new(1998, 11, 11)
    GULF_WAR_RANGE = (Date.new(1990, 8, 2)..NOV_1998)

    # Temporary comment: Added by TT1
    #
    # The following comment was copied from app/models/emis_redis/military_information.rb
    # which is being depcreated.
    #
    # In https://github.com/department-of-veterans-affairs/va.gov-team/issues/41046
    # we updated the military service branches to use an updated list from
    # Lighthouse BRD. The list below combines the branches from the former list
    # that was in the previous vets_json_schema, and the new list, from BRD. In
    # the future, we may consider udpating this constant to a dynamic value
    # populated by a call to Lighthouse BRD, but that is not necessary now.
    COMBINED_SERVICE_BRANCHES = [
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

    def initialize(user)
      @service = VAProfile::MilitaryPersonnel::Service.new(user)
    end

    # Temporary comment: Added by TT1
    #
    # @return [Boolean] true if the user is currently
    #  serving in active duty
    def currently_active_duty
      currently_active_duty_hash[:yes]
    end

    # Temporary comment: Added by TT1
    #
    # @return [Hash] currently active duty data in hash format
    def currently_active_duty_hash
      is_active = false

      service_episodes_by_date.each do |episode|
        if episode.end_date && (episode.end_date.empty? || DateTime.parse(episode.end_date).to_date.future?)
          is_active = true
          break
        end
      end

      { yes: is_active }
    end

    def deployments
      @deployments ||= lambda do
        return_val = []

        service_history.episodes.each do |episode|
          return_val += episode.deployments if episode.deployments.present?
        end

        return_val
      end.call
    end

    def discharge_type
      return if latest_service_episode.blank?

      DISCHARGE_TYPES[latest_service_episode&.character_of_discharge_code]
    end

    # Temporary comment: Added by TT1
    #
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

    def hca_last_service_branch
      HCA_SERVICE_BRANCHES[latest_service_episode&.branch_of_service_code] || 'other'
    end

    def last_discharge_date
      latest_service_episode&.end_date
    end

    def last_entry_date
      latest_service_episode&.begin_date
    end

    # Temporary comment: Added by TT1
    #
    # @return [String] Last service branch the veteran served under in
    #  readable format
    def last_service_branch
      latest_service_episode&.branch_of_service
    end

    # Temporary comment: Added by TT1
    #
    # @return [Hash] Date range of the most recently completed service
    #  in the guard or reserve service.
    def latest_guard_reserve_service_period
      guard_reserve_service_history.try(:[], 0)
    end

    def military_service_episodes
      service_history.episodes.find_all do |episode|
        episode.service_type == 'Military Service'
      end
    end

    def post_nov111998_combat
      deployments.each do |deployment|
        return true if Date.parse(deployment['deployment_end_date']) > NOV_1998
      end

      false
    end

    def service_branches
      military_service_episodes.map(&:branch_of_service_code).uniq
    end

    def service_episodes_by_date
      @service_episodes_by_date ||= military_service_episodes.sort_by do |ep|
        if ep.end_date.blank?
          Time.zone.today + 3650
        else
          Date.parse(ep.end_date)
        end
      end.reverse
    end

    # Temporary comment: Added by TT1
    #
    # @return [Array<Hash>] Data about the veteran's service periods
    #  including service branch served under and date range of each
    #  service period, used only for Form 526 - Disability form
    def service_periods
      military_service_episodes_by_date.map do |military_service_episode|
        service_branch = service_branch_used_in_disability(military_service_episode)
        return {} unless service_branch

        {
          service_branch:,
          date_range: {
            from: military_service_episode.begin_date,
            to: military_service_episode.end_date
          }
        }
      end
    end

    def sw_asia_combat
      deployed_to?(SOUTHWEST_ASIA, GULF_WAR_RANGE)
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

    private

    def deployed_to?(countries, date_range)
      deployments.each do |deployment|
        deployment['deployment_locations'].each do |location|
          location_date_range = location['deployment_location_begin_date']..location['deployment_location_end_date']

          if countries.include?(location['deployment_country_code']) && date_range.overlaps?(location_date_range)
            return true
          end
        end
      end

      false
    end

    # Temporary comment: Added by TT1
    #
    # @return [Array<Hash] array of veteran's Guard and reserve service periods by period of service end date, DESC
    def guard_reserve_service_by_date
      military_service_episodes_by_date.select do |episode|
        code = episode.personnel_category_type_code
        national_guard?(code) || reserve?(code)
      end.sort_by(&:end_date)
                                       .reverse
    end

    def latest_service_episode
      service_episodes_by_date.try(:[], 0)
    end

    # Temporary comment: Added by TT1
    #
    # episodes is an array of Military Services Episodes and Service Academy Episodes. We're only
    #  interested in Military Service Episodes, so we filter out the Service Academy Episodes by checking
    #  if the episode has a period_of_service_end_date.
    def military_service_episodes_by_date
      service_episodes_by_date.select do |episode|
        episode.service_type == 'Military Service'
      end
    end

    # Temporary comment: Added by TT1
    def national_guard?(code)
      code == 'N'
    end

    # Temporary comment: Added by TT1
    def reserve?(code)
      %w[V Q].include?(code)
    end

    # Temporary comment: Added by TT1
    #
    # Convert period of service type code from a military service episode
    # into a formatted readable string.
    # EVSS requires the reserve/national guard category to be a part
    # of the period of service type field.
    # @param military_service_episode [Hash]
    # Military service episode model
    # @return [String] Readable service branch name formatted for EVSS
    def service_branch_used_in_disability(military_service_episode)
      category = case military_service_episode.personnel_category_type_code
                 when 'N'
                   'National Guard'
                 when 'V', 'Q'
                   'Reserve'
                 else
                   ''
                 end

      service_name = "#{military_service_episode.branch_of_service} #{category}".strip
      service_name.gsub!('Air Force National Guard', 'Air National Guard')
      service_name if COMBINED_SERVICE_BRANCHES.include? service_name
    end

    def service_history
      @service_history ||= @service.get_service_history
    end
  end
end
