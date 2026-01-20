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

        # Apply same logic as va.gov - sets health_care_system_name on each record
        resource = MyHealth::FacilitiesHelper.set_health_care_system_names(resource)

        resource = resource.sort(params[:sort])

        # Extract unique care systems for metadata
        resource.metadata[:care_systems] = extract_unique_care_systems(resource.records)

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }
        render json: AllTriageTeamsSerializer.new(resource.data, options)
      end

      private

      def extract_unique_care_systems(all_recipients)
        all_recipients.uniq(&:station_number).map do |team|
          {
            station_number: team.station_number,
            health_care_system_name: team.health_care_system_name
          }
        end
      end
    end
  end
end
