# frozen_string_literal: true

module MyHealth
  module V1
    class AllergiesController < MRController
      def index
        # EXPERIMENTAL - new allergies model not yet implemented
        #
        # if Flipper.enabled?(:mhv_medical_records_support_new_model_allergy)
        #   use_cache = params.key?(:use_cache) ? ActiveModel::Type::Boolean.new.cast(params[:use_cache]) : true

        #   with_patient_resource(client.list_allergies(@current_user.uuid, use_cache:)) do |resource|
        #     resource = resource.sort
        #     if pagination_params[:per_page]
        #       resource = resource.paginate(**pagination_params)
        #       links = pagination_links(resource) if pagination_params[:per_page]
        #     end
        #     options = { meta: resource.metadata, links: }
        #     render json: AllergySerializer.new(resource.data, options)
        #   end
        # else
        render_resource client.list_allergies(@current_user.uuid)
        # end
      end

      def show
        allergy_id = params[:id].try(:strip)
        # EXPERIMENTAL - new allergies model not yet implemented
        #
        # if Flipper.enabled?(:mhv_medical_records_support_new_model_allergy)
        #   with_patient_resource(client.get_allergy(allergy_id)) do |resource|
        #     raise Common::Exceptions::RecordNotFound, allergy_id if resource.blank?

        #     render json: AllergySerializer.new(resource)
        #   end
        # else
        render_resource client.get_allergy(allergy_id)
        # end
      end
    end
  end
end
