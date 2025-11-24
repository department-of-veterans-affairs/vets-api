# frozen_string_literal: true

module MyHealth
  module V2
    class PrescriptionDocumentationController < RxController
      def search
        ndc = params[:ndc]
        if ndc.blank?
          render json: { error: 'NDC number is required' }, status: :bad_request
          return
        end

        # Fetch prescription documentation using the NDC number
        # https://api.krames.com/v3/content/search?ndc=<NDC>
        #
        # Drug documentation JSON object from the API
        documentation = client.get_rx_documentation(ndc)
        # Build PrescriptionDocumentation object
        # https://api.krames.com/v3/content/<ContentType>-<ContentID>
        #
        # PrescriptionDocumentation object with HTML content containing drug information
        prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
        render json: MyHealth::V2::PrescriptionDocumentationSerializer.new(prescription_documentation)
      rescue Common::Exceptions::BackendServiceException => e
        if e.original_status == 404
          render json: { error: 'Documentation not found for this NDC' }, status: :not_found
        else
          raise e
        end
      rescue Common::Exceptions::BaseError => e
        raise e
      rescue => e
        render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
      end
    end
  end
end
