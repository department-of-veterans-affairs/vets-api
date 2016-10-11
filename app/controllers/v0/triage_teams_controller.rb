# frozen_string_literal: true
module V0
  class TriageTeamsController < SMController
    SORT_FIELDS   = %w(name).freeze
    SORT_TYPES    = (SORT_FIELDS + SORT_FIELDS.map { |field| "-#{field}" }).freeze
    DEFAULT_SORT  = '-name'

    def index
      resource = client.get_triage_teams
      resource = resource.sort(params[:sort] || DEFAULT_SORT, allowed: SORT_TYPES)

      raise Common::Exceptions::InternalServerError unless resource.present?

      render json: resource.data,
             serializer: CollectionSerializer,
             each_serializer: TriageTeamSerializer,
             meta: resource.metadata
    end
  end
end
