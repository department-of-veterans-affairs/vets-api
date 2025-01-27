# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedEntitiesForAppointController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      def index
        data = RepresentationManagement::AccreditedEntityQuery.new(params[:query]).results
        json_response = data.map do |record|
          if record.is_a?(AccreditedIndividual)
            RepresentationManagement::AccreditedEntities::IndividualSerializer.new(record).serializable_hash
          elsif record.is_a?(AccreditedOrganization)
            RepresentationManagement::AccreditedIndividuals::OrganizationSerializer.new(record).serializable_hash
          end
        end
        render json: json_response
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
