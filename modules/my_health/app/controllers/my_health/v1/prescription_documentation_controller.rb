# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        if Flipper.enabled?(:mhv_medications_display_documentation_content, @current_user)
          begin
            id = params[:id]
            rx = client.get_rx_details(id)
            raise StandardError, 'Rx not found' if rx.nil?

            cmop_ndc_number = if rx[:rx_rf_records]&.[](0)&.[](1)&.[](0)&.key?(:cmop_ndc_number)
                                rx[:rx_rf_records][0][1][0][:cmop_ndc_number]
                              elsif rx[:cmop_ndc_number].present?
                                rx[:cmop_ndc_number]
                              end
            raise StandardError, 'Missing NDC number' if cmop_ndc_number.nil?

            documentation = client.get_rx_documentation(cmop_ndc_number)
            prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
            render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
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
