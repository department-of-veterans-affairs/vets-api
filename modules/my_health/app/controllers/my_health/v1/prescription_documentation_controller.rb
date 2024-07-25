# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        if Flipper.enabled?(:mhv_medications_display_documentation_content, @current_user)
          begin
            documentation = client.get_rx_documentation(params[:ndc])
            render json: PrescriptionDocumentation.new({ html: documentation[:data] }),
                   serializer: PrescriptionDocumentationSerializer
          rescue => e
            render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
          end
        else
          render json: { error: 'Documentation is not available' }, status: :not_found
        end
      end
    end
  end
end
