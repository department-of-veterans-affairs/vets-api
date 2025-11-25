# frozen_string_literal: true

module MyHealth
  module V1
    class ConditionsController < MRController
      def index
        # EXPERIMENTAL - new conditions model not yet implemented
        #
        # if Flipper.enabled?(:mhv_medical_records_support_new_model_health_condition)
        #   use_cache = params.key?(:use_cache) ? ActiveModel::Type::Boolean.new.cast(params[:use_cache]) : true

        #   with_patient_resource(client.list_conditions(@current_user.uuid, use_cache:)) do |resource|
        #     resource = resource.sort
        #     if pagination_params[:per_page]
        #       resource = resource.paginate(**pagination_params)
        #       links = pagination_links(resource) if pagination_params[:per_page]
        #     end
        #     options = { meta: resource.metadata, links: }
        #     render json: HealthConditionSerializer.new(resource.data, options)
        #   end
        # else
        render_resource client.list_conditions(@current_user.uuid)
        # end
      end

      def show
        condition_id = params[:id].try(:to_i)
        # EXPERIMENTAL - new conditions model not yet implemented
        #
        # if Flipper.enabled?(:mhv_medical_records_support_new_model_health_condition)
        #   with_patient_resource(client.get_condition(condition_id)) do |resource|
        #     raise Common::Exceptions::RecordNotFound, condition_id if resource.blank?

        #     render json: HealthConditionSerializer.new(resource)
        #   end
        # else
        render_resource client.get_condition(condition_id)
        # end
      end
    end
  end
end
