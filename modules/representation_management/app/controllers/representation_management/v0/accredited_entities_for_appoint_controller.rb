# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedEntitiesForAppointController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      # before_action :feature_enabled

      def index
        data = RepresentationManagement::AccreditedEntityQuery.new(params[:query]).results
        render json: data.map { |record|
                       RepresentationManagement::AccreditedEntities::EntitySerializer.new(record).serializable_hash
                     }
      end

      # def feature_enabled
      #   routing_error unless Flipper.enabled?(:find_a_representative_use_accredited_models)
      # end
    end
  end
end
