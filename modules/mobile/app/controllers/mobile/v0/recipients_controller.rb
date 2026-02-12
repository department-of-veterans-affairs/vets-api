# frozen_string_literal: true

module Mobile
  module V0
    class RecipientsController < MessagingController
      def recipients
        resource = client.get_triage_teams(@current_user.uuid, use_cache?)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource = resource.sort(params[:sort])

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        render json: TriageTeamSerializer.new(resource.data, options)
      end

      def all_recipients
        resource = client.get_all_triage_teams(@current_user.uuid)
        raise Common::Exceptions::ResourceNotFound if resource.blank?

        resource.records = resource.records.reject(&:blocked_status)
        resource.records = resource.records.select(&:preferred_team)
        resource = resource.sort(params[:sort])

        resource.metadata[:care_systems] = if Flipper.enabled?(:mhv_secure_messaging_612_care_systems_fix, @user)
                                             get_unique_care_systems612_fix(resource.records)
                                           else
                                             get_unique_care_systems(resource.records)
                                           end

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        render json: AllTriageTeamsSerializer.new(resource.data, options)
      end

      private

      def get_unique_care_systems(all_recipients)
        unique_care_system_ids = all_recipients.uniq(&:station_number).map(&:station_number)
        map_care_systems(unique_care_system_ids)
      end

      def get_unique_care_systems612_fix(all_recipients)
        unique_care_system_ids = all_recipients.uniq(&:station_number).map(&:station_number)
        included_complex_systems = MyHealth::FacilitiesHelper::COMPLICATED_SYSTEMS.keys & unique_care_system_ids
        unique_care_system_ids -= included_complex_systems
        care_system_map = map_care_systems(unique_care_system_ids)
        included_complex_systems.each do |system_id|
          care_system_map << {
            station_number: system_id,
            health_care_system_name: MyHealth::FacilitiesHelper::COMPLICATED_SYSTEMS[system_id]
          }
        end
        care_system_map
      end

      def map_care_systems(unique_care_system_ids)
        unique_care_system_names = fetch_facility_names(unique_care_system_ids)
        unique_care_system_ids.zip(unique_care_system_names).map do |system|
          {
            station_number: system[0],
            health_care_system_name: system[1] || system[0]
          }
        end
      end

      def fetch_facility_names(unique_care_system_ids)
        Mobile::FacilitiesHelper.get_facility_names(unique_care_system_ids)
      rescue => e
        # log the error but don't prevent allrecipients from being returned
        StatsD.increment('mobile.sm.allrecipients.facilities_lookup.failure')
        Rails.logger.error('Lighthouse Facilities API error for allrecipients',
                           error: e.message, user_uuid: @current_user&.uuid)
        # Return nil for each facility so fallback to station_number occurs
        Array.new(unique_care_system_ids.size)
      end
    end
  end
end
