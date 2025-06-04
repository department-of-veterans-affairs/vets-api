# frozen_string_literal: true

module MyHealth
  module V1
    class AllergiesController < MRController
      def index
        if Flipper.enabled?(:mhv_medical_records_support_new_model_allergy)
          with_patient_resource(client.list_allergies(@current_user.uuid)) do |resource|
            resource = resource.sort('-date')
            if pagination_params[:per_page]
              resource = resource.paginate(**pagination_params)
              links = pagination_links(resource) if pagination_params[:per_page]
            end
            options = { meta: resource.metadata, links: }
            render json: AllergySerializer.new(resource.data, options)
          end
        else
          render_resource client.list_allergies(@current_user.uuid)
        end
      end

      def show
        allergy_id = params[:id].try(:strip)
        if Flipper.enabled?(:mhv_medical_records_support_new_model_allergy)
          with_patient_resource(client.get_allergy(allergy_id)) do |resource|
            raise Common::Exceptions::RecordNotFound, allergy_id if resource.blank?

            options = { meta: resource.metadata }
            render json: AllergySerializer.new(resource, options)
          end
        else
          render_resource client.get_allergy(allergy_id)
        end
      end
    end
  end
end
