# frozen_string_literal: true

module Mobile
  module V0
    class TriageTeamsController < MessagingController
      def index
        use_all_triage_teams = Flipper.enabled?(:mobile_get_expanded_triage_teams, @current_user)

        resource = if use_all_triage_teams

                     # TODO: add parameter to get OH data from BE
                     #
                     # Use get_all_triage_teams and filter out blocked teams
                     all_teams = client.get_all_triage_teams(@current_user.uuid, use_cache? || true)
                     raise Common::Exceptions::ResourceNotFound if all_teams.blank?

                     # Filter out blocked teams
                     filtered_teams = Mobile::V0::Adapters::TriageTeamAdapter.filter_blocked_teams(all_teams.data)

                     # Create new Common::Collection with filtered data but keep original metadata
                     Common::Collection.new(AllTriageTeams, data: filtered_teams, metadata: all_teams.metadata)
                   else
                     # Use standard get_triage_teams method (existing behavior)
                     triage_teams = client.get_triage_teams(@current_user.uuid, use_cache? || true)
                     raise Common::Exceptions::ResourceNotFound if triage_teams.blank?

                     triage_teams
                   end

        resource = resource.sort(params[:sort])

        # Even though this is a collection action we are not going to paginate
        options = { meta: resource.metadata }

        if use_all_triage_teams
          render json: AllTriageTeamsSerializer.new(resource.data, options)
        else
          render json: TriageTeamSerializer.new(resource.data, options)
        end
      end
    end
  end
end
