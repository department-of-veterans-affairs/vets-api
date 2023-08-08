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
        military_personnel_service.service_episodes_by_date.each do |episode|
          if episode['period_of_service_end_date']
            date = episode['period_of_service_end_date']
            return date.empty? || DateTime.parse(date).to_date.future?
          else
            return false
          end
        end
      end

      # @return [Hash] currently active duty data in hash format
      def currently_active_duty_hash
        # we can get the dates and figure it out that way, or we can 
        # make a separate call to a different bio path. 
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

    def service_periods; end

    def guard_reserve_service_history; end

    def latest_guard_reserve_service_period; end
    
    private
    
    def disability_data
      @disability_data ||= disability_service.get_disability_data
    end
  end
end
