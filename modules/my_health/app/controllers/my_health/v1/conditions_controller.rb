# frozen_string_literal: true

module MyHealth
  module V1
    class ConditionsController < MRController
      def index
        if Flipper.enabled?(:mhv_medical_records_support_new_model_health_condition)
          with_patient_resource(client.list_conditions) do |resource|
            resource = resource.paginate(**pagination_params) if pagination_params[:per_page]

            links = pagination_links(resource)
            options = { meta: resource.metadata, links: }
            render json: HealthConditionSerializer.new(resource.data, options)
          end
        else
          render_resource client.list_conditions
        end
      end

      def show
        condition_id = params[:id].try(:to_i)
        if Flipper.enabled?(:mhv_medical_records_support_new_model_health_condition)
          with_patient_resource(client.get_condition(condition_id)) do |resource|
            raise Common::Exceptions::RecordNotFound, condition_id if resource.blank?

            options = { meta: resource.metadata }
            render json: HealthConditionSerializer.new(resource, options)
          end
        else
          render_resource client.get_condition(condition_id)
        end
      end
    end
  end
end
