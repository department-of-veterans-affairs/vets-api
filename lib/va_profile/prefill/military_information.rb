# frozen_string_literal: true

require 'va_profile/disability/service'
require 'va_profile/military_personnel/service'

module VAProfile
  module Prefill
    class MilitaryInformation
      PREFILL_METHODS = %w[
        compensable_va_service_connected
        currently_active_duty
        currently_active_duty_hash
        discharge_type
        guard_reserve_service_history
        hca_last_service_branch
        is_va_service_connected
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
        va_compensation_type
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

      # Disability ratings counted as lower
      LOWER_DISABILITY_RATINGS = [10, 20, 30, 40].freeze

      # Disability ratings counted as higher
      HIGHER_DISABILITY_RATING = 50

      # In https://github.com/department-of-veterans-affairs/va.gov-team/issues/41046
      # military service branches were modified to use an updated list from
      # Lighthouse BRD. The list below combines the branches from the former list
      # that was in the previous vets_json_schema, and the new list, from BRD. In
      # the future, consider udpating this constant to a dynamic value populated
      # by a call to Lighthouse BRD.
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

      attr_reader :disability_service, :military_personnel_service

      def initialize(user)
        @disability_service = VAProfile::Disability::Service.new(user)
        @military_personnel_service = VAProfile::MilitaryPersonnel::Service.new(user)
      end

      # @return [Boolean] true if veteran is paid for a disability
      #  with a high disability percentage
      #
      # Rubocop wants this method to be named va_service_connected? but is_va_service_connected
      # is the name of the method we're replacing.
      #
      # rubocop:disable Naming/PredicateName
      def is_va_service_connected
        combined_service_connected_rating_percentage >= HIGHER_DISABILITY_RATING
      end
      # rubocop:enable Naming/PredicateName

      # @return [Boolean] true if veteran is paid for a disability
      #  with a low disability percentage
      def compensable_va_service_connected
        LOWER_DISABILITY_RATINGS.include?(combined_service_connected_rating_percentage)
      end

      # @return [String] If veteran is paid for a disability, this method will
      #  return which type of disability it is: highDisability or lowDisability
      def va_compensation_type
        high_disability = is_va_service_connected
        low_disability = compensable_va_service_connected

        if high_disability
          'highDisability'
        elsif low_disability
          'lowDisability'
        end
      end

      # @return [Boolean] true if the user is currently
      #  serving in active duty
      def currently_active_duty
        currently_active_duty_hash[:yes]
      end

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

      # @return [String] Last service branch the veteran served under in
      #  readable format
      def last_service_branch
        latest_service_episode&.branch_of_service
      end

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
          return true if deployment['deployment_end_date'] && (Date.parse(deployment['deployment_end_date']) > NOV_1998)
        end

        false
      end

      # @return [Array<String>] Veteran's unique service branch codes
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

      # @return [Array<Hash>] Data about the veteran's service periods
      #  including service branch served under and date range of each
      #  service period; used only for Form 526 - Disability form
      def service_periods
        valid_episodes = military_service_episodes_by_date.select do |military_service_episode|
          service_branch_used_in_disability(military_service_episode)
        end
        valid_episodes.map do |valid_episode|
          {
            service_branch: service_branch_used_in_disability(valid_episode),
            date_range: {
              from: valid_episode.begin_date,
              to: valid_episode.end_date
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

      def combined_service_connected_rating_percentage
        disability_data&.disability_rating&.combined_service_connected_rating_percentage&.to_i || 0
      end

      def disability_data
        @disability_data ||= disability_service.get_disability_data
      end

      def deployed_to?(countries, date_range)
        deployments.each do |deployment|
          deployment['deployment_locations']&.each do |location|
            location_date_range = location['deployment_location_begin_date']..location['deployment_location_end_date']

            if countries.include?(location['deployment_country_code']) && date_range.overlaps?(location_date_range)
              return true
            end
          end
        end

        false
      end

      # @return [Array<Hash] array of veteran's Guard and reserve service periods by period of service end date, DESC
      def guard_reserve_service_by_date
        military_service_episodes_by_date.select do |episode|
          code = episode.personnel_category_type_code
          national_guard?(code) || reserve?(code)
        end.sort_by(&:end_date).reverse
      end

      def latest_service_episode
        service_episodes_by_date.try(:[], 0)
      end

      # episodes is an array of Military Services Episodes and Service Academy Episodes. We're only
      #  interested in Military Service Episodes, so we filter out the Service Academy Episodes by checking
      #  if the episode has a period_of_service_end_date.
      def military_service_episodes_by_date
        service_episodes_by_date.select do |episode|
          episode.service_type == 'Military Service'
        end
      end

      def national_guard?(code)
        code == 'N'
      end

      def reserve?(code)
        %w[V Q].include?(code)
      end

      # Convert period of service type code from a military service episode
      #  into a formatted readable string.
      # EVSS requires the reserve/national guard category to be a part
      #  of the period of service type field.
      # @param military_service_episode [Hash]
      #  Military service episode model
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
        @service_history ||= @military_personnel_service.get_service_history
      end
    end
  end
end
