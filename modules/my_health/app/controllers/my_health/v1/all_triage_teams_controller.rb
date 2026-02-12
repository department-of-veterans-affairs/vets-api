# frozen_string_literal: true

module MyHealth
  module V1
    class AllTriageTeamsController < SMController
      include Vets::SharedLogging

      STATSD_KEY_PREFIX = 'api.my_health.all_triage_teams'

      def index
        resource = client.get_all_triage_teams(@current_user.uuid)
        if resource.blank?
          raise Common::Exceptions::RecordNotFound,
                "Triage teams for user ID #{@current_user.uuid} not found"
        end
        resource = MyHealth::FacilitiesHelper.set_health_care_system_names(resource)

        resource = resource.sort(params.permit(:sort)[:sort])

        # Even though this is a collection action we are not going to paginate
        render json: AllTriageTeamsSerializer.new(resource.data, { meta: resource.metadata })
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.fail")
        log_exception_to_rails(e)
        raise e
      end
    end
  end
end
