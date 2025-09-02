# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
          begin
            id = params[:id]
            rx = client.get_rx_details(id)
            raise StandardError, 'Rx not found' if rx.nil?
            raise StandardError, 'Missing NDC number' if rx.cmop_ndc_value.nil?

            documentation = client.get_rx_documentation(rx.cmop_ndc_value)
            prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
            render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
          rescue => e
            render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
          end
      end
    end
  end
end
