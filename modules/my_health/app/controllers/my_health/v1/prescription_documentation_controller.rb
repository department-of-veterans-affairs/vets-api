# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < MyHealth::RxController
      def index
        if Flipper.enabled?(:mhv_medications_display_documentation_content, @current_user)
          begin
            id = params[:id]
            rx = client.get_rx_details(id)
            raise StandardError, 'Rx not found' if rx.nil?

            cmop_ndc_number = rx.rx_rf_records&.dig(0, 1)&.find do |record|
              record[:cmop_ndc_number]
            end&.[](:cmop_ndc_number) || rx[:cmop_ndc_number].presence
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
