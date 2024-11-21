# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedEntitiesForAppointController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      def index
        p "params: #{params}", "params[:query]: #{params[:query]}"
        p "AccreditedIndividuals: #{AccreditedIndividual.all.each(&:inspect)}"
        p "AccreditedOrganizations: #{AccreditedOrganization.all.each(&:inspect)}"
        data = RepresentationManagement::AccreditedEntityQuery.new(params[:query]).results
        p "RepresentationManagement::AccreditedEntitiesForAppointController#index data: #{data}"
        json_response = data.map do |record|
          if record.is_a?(AccreditedIndividual)
            RepresentationManagement::AccreditedEntities::IndividualSerializer.new(record).serializable_hash
          elsif record.is_a?(AccreditedOrganization)
            RepresentationManagement::AccreditedIndividuals::OrganizationSerializer.new(record).serializable_hash
          end
        end
        render json: json_response
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
