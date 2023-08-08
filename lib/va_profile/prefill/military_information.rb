# require 'hca/military_information'
require 'va_profile/military_personnel/service'

module VAProfile
  module Prefill
    class MilitaryInformation
      PREFILL_METHODS = %i[
        last_service_branch
        currently_active_duty
        currently_active_duty_hash
        is_va_service_connected
        compensable_va_service_connected
        va_compensation_type
        service_periods
        guard_reserve_service_history
        latest_guard_reserve_service_period
      ].freeze  # map all of these to VAProfile.

      # The following methods have been implemented
      # - last_service_branch
      # - is_va_service_connected
      # - compensable_va_service_connected
      # - va_compensation_type

      # Disability ratings counted as lower
      LOWER_DISABILITY_RATINGS = [10, 20, 30, 40].freeze

      # Disability ratings counted as higher
      HIGHER_DISABILITY_RATING = 50

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


      attr_reader :military_personnel_service, :disability_service, :disability_data

      def initialize(user)
        @military_personnel_service = HCA::MilitaryInformation(user)
        @disability_service = VAProfile::Disability::Service.new(user)
      end

      # @return [String] Last service branch the veteran served under in
      #  readable format
      def last_service_branch
        military_personnel_service.latest_service_episode&.branch_of_service
      end

      # @return [Boolean] true if the user is currently
      #  serving in active duty
      def currently_active_duty
        currently_active_duty_hash[:yes]
      end

      # @return [Hash] currently active duty data in hash format
      def currently_active_duty_hash
        military_personnel_service.service_episodes_by_date.each do |episode|
          value =
            if episode['period_of_service_end_date']
              date = episode['period_of_service_end_date']
              date.empty? || DateTime.parse(date).to_date.future?
            else
              false
            end

          return { yes: value }
        end
      end

      # @return [Boolean] true if veteran is paid for a disability
      #  with a high disability percentage
      def is_va_service_connected
        disability_data.combined_service_connected_rating_percentage >= HIGHER_DISABILITY_RATING
      end

      # @return [Boolean] true if veteran is paid for a disability
      #  with a low disability percentage
      def compensable_va_service_connected
        LOWER_DISABILITY_RATINGS.include?(disability_data.combined_service_connected_rating_percentage)
      end

      # @return [String] If veteran is paid for a disability, this method will
      #  return which type of disability it is: highDisability or lowDisability
      def va_compensation_type
        # while supporting fallback support for the old fields,
        # make a consistent number of calls to the properties to
        # support specs that will be removed or updated
        ## I DON'T UNDERSTAND THESE ^^ COMMENTS. TAKEN FROM EMIS SIDE.
        high_disability = is_va_service_connected
        low_disability = compensable_va_service_connected

        if high_disability
          'highDisability'
        elsif low_disability
          'lowDisability'
        end          
      end
    end

    # @return [Array<Hash>] Data about the veteran's service periods
    #  including service branch served under and date range of each
    #  service period, used only for Form 526 - Disability form
    #
    # service_episodes_by_date returns and array of Military Services Episodes
    #  and Service Academy Episodes. We're only interested in Military Service
    #  Episodes, so we filter out the Service Academy Episodes by checking if
    #  the episode has a period_of_service_end_date.
    def service_periods
        military_service_episodes(military_personnel_service.service_episodes_by_date).map do |military_service_episode|
        service_branch = service_branch_used_in_disability(military_service_episode)
        return {} unless service_branch

        {
          service_branch:,
          date_range: {
            from: military_service_episode['period_of_service_begin_date'],
            to: military_service_episode['period_of_service_end_date']
          }
        }
      end
    end

    # @return [Array<Hash>] Veteran's guard and reserve service episode date
    #  ranges sorted by end_date
    def guard_reserve_service_history
      guard_reserve_service_by_date.map do |period|
        {
          from: period['period_of_service_begin_date']
          to: period['period_of_service_end_date']
        }
      end
    end

    # @return [Hash] Cached array of veteran's Guard and reserve service
    # periods sorted by end date
    def latest_guard_reserve_service_period
      guard_reserve_service_history.try(:[], 0)
    end
    
    private
    
    def disability_data
      @disability_data ||= disability_service.get_disability_data
    end

    # Convert period of service type code from a military service episode
    # into a formatted readable string.
    # EVSS requires the reserve/national guard category to be a part
    # of the period of service type field.
    # @param military_service_episode [Hash]
    # Military service episode model
    # @return [String] Readable service branch name formatted for EVSS
    def service_branch_used_in_disability(military_service_episode)
      category = case military_service_episode['period_of_service_type_code']
                 when 'A'
                   ''
                 when 'N'
                   'National Guard'
                 when 'V' || 'Q'
                   'Reserve'
                 else
                   ''
                 end

      service_name = "#{military_service_episode['branch_of_service_text']} #{category}".strip
      service_name.gsub!('Air Force National Guard', 'Air National Guard')
      service_name if COMBINED_SERVICE_BRANCHES.include? service_name
    end
  end

  private
  
  # episodes returns an array of Military Services Episodes
  #  and Service Academy Episodes. We're only interested in Military Service
  #  Episodes, so we filter out the Service Academy Episodes by checking if
  #  the episode has a period_of_service_end_date.
  def military_service_episodes(episodes)
    service_episodes_by_date.select do |episode|
      episode['period_of_service_end_date']
    end
  end

  # @return Array<Hash>
  def guard_reserve_service_by_date
    military_service_episodes(military_personnel_service.service_episodes_by_date).each_with_object([]) do |episode, guard_details|
      guard_details.concat(episode['guard_reserve_periods'])
    end.sort_by { |guard_detail| guard_detail['period_of_service_end_date'] }.reverse
  end
end
