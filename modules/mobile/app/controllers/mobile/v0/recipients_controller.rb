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
        resource = client.get_all_triage_teams(@current_user.uuid, use_cache?)
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
        unique_care_system_names = Mobile::FacilitiesHelper.get_facility_names(unique_care_system_ids)
        unique_care_system_ids.zip(unique_care_system_names).map! do |system|
          {
            station_number: system[0],
            health_care_system_name: system[1] || system[0]
          }
        end
      end

      def get_unique_care_systems612_fix(all_recipients)
        unique_care_system_ids = all_recipients.uniq(&:station_number).map(&:station_number)
        does_include612 = unique_care_system_ids.delete('612')
        unique_care_system_names = Mobile::FacilitiesHelper.get_facility_names(unique_care_system_ids)
        care_system_map = unique_care_system_ids.zip(unique_care_system_names).map! do |system|
          {
            station_number: system[0],
            health_care_system_name: system[1] || system[0]
          }
        end

        if does_include612
          care_system_map << {
            station_number: '612',
            health_care_system_name: 'VA Northern California'
          }
        end
        care_system_map
      end
    end
  end
end
