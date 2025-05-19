# frozen_string_literal: true

module MyHealth
  module V1
    class VaccinesController < MRController
      def index
        if Flipper.enabled?(:mhv_medical_records_support_new_model_vaccine)
          with_patient_resource(client.list_vaccines) do |resource|
            if pagination_params[:per_page]
              resource = resource.paginate(**pagination_params)
              links = pagination_links(resource) if pagination_params[:per_page]
            end
            options = { meta: resource.metadata, links: }
            render json: VaccineSerializer.new(resource.data, options)
          end
        else
          render_resource client.list_vaccines
        end
      end

      def show
        vaccine_id = params[:id].try(:to_i)
        if Flipper.enabled?(:mhv_medical_records_support_new_model_vaccine)
          with_patient_resource(client.get_vaccine(vaccine_id)) do |resource|
            raise Common::Exceptions::RecordNotFound, vaccine_id if resource.blank?

            options = { meta: resource.metadata }
            render json: VaccineSerializer.new(resource, options)
          end
        else
          render_resource client.get_vaccine(vaccine_id)
        end
      end
    end
  end
end
