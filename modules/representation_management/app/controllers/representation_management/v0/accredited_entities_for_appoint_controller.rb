# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedEntitiesForAppointController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      def index
        data = RepresentationManagement::AccreditedEntityQuery.new(
          params[:query],
          data_source_log: current_data_source_log
        ).results

        json_response = data.map do |record|
          # Handle both AccreditedIndividual and VeteranRepresentativeAdapter
          if record.is_a?(AccreditedIndividual) || record.is_a?(RepresentationManagement::VeteranRepresentativeAdapter)
            RepresentationManagement::AccreditedEntities::IndividualSerializer.new(record).serializable_hash
          elsif record.is_a?(AccreditedOrganization) || record.is_a?(RepresentationManagement::AccreditedOrganizationAdapter)
            RepresentationManagement::AccreditedIndividuals::OrganizationSerializer.new(record).serializable_hash
          end
        end

        render json: json_response
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_use_accredited_models)
      end

      def current_data_source_log
        @current_data_source_log ||=
          RepresentationManagement::AccreditationDataIngestionLog.most_recent_successful
      end
    end
  end
end
