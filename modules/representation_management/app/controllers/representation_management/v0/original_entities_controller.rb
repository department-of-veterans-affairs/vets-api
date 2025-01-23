# frozen_string_literal: true

module RepresentationManagement
  module V0
    class OriginalEntitiesController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      def index
        data = RepresentationManagement::OriginalEntityQuery.new(params[:query]).results
        json_response = data.map do |record|
          if record.is_a?(Veteran::Service::Representative)
            RepresentationManagement::OriginalEntities::RepresentativeSerializer.new(record).serializable_hash
          elsif record.is_a?(Veteran::Service::Organization)
            RepresentationManagement::OriginalEntities::OrganizationSerializer.new(record).serializable_hash
          end
        end
        render json: json_response
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:use_veteran_models_for_appoint)
      end
    end
  end
end
