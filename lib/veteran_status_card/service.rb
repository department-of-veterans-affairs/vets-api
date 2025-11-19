# frozen_string_literal: true

module VeteranStatusCard
  class Service
    def initialize(user)
      @user = user
    end

    def status_card
      service_history = latest_service_history
      vet_status = vet_verification_status

      {
        user_percent_of_disability: disability_rating
      }
    end

    private

    def full_name
      @user.full_name_normalized
    end

    def disability_rating
      lighthouse? ? lighthouse_rating : evss_rating
    end

    def lighthouse?
      Flipper.enabled?(:profile_lighthouse_rating_info, @user)
    end

    def lighthouse_rating
      lighthouse_disabilities_provider.get_combined_disability_rating
    end

    def lighthouse_disabilities_provider
      @lighthouse_disabilities_provider ||= LighthouseRatedDisabilitiesProvider.new(@user.icn)
    end

    def evss_rating
      evss_service.get_rating_info
    end

    def evss_service
      @evss_service ||= EVSS::CommonService(auth_headers)
    end

    def auth_headers
      EVSS::DisabilityCompensationAuthHeaders.new(@user).add_headers(EVSS::AuthHeaders.new(@user).to_h)
    end

    def latest_service_history
      response = military_personnel_service.get_service_history

      # Get the most recent service episode (episodes are sorted by begin_date, oldest first)
      last_service = response.episodes.last

      {
        branch_of_service: last_service&.branch_of_service,
        latest_service_date_range: format_service_date_range(last_service)
      }
    end

    def format_service_date_range(service_episode)
      return nil unless service_episode

      {
        begin_date: service_episode.begin_date,
        end_date: service_episode.end_date
      }
    end

    def military_personnel_service
      @military_personnel_service ||= VAProfile::MilitaryPersonnel::Service.new(@user)
    end

    def vet_verification_status
      response = vet_verification_service.get_vet_verification_status(@user.icn)
      {
        veteran_status: response.dig('data', 'attributes', 'veteran_status'),
        reason: response.dig('data', 'attributes', 'not_confirmed_reason'),
        message: response.dig('data', 'message'),
        title: response.dig('data', 'title'),
        status: response.dig('data', 'status')
      }
    end

    def vet_verification_service
      @vet_verification_service ||= VeteranVerification::Service.new
    end
  end
end
