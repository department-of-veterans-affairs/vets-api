# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        id = params[:id]
        rx = client.get_rx_details(id)
        raise StandardError, 'Rx not found' if rx.nil?
        raise StandardError, 'Missing NDC number' if rx.cmop_ndc_value.nil?
        # Get Prescription Documentation Endpoint
        # https://api.krames.com/v3/content/search?ndc=<NDC>
        #
        # @param [rx.cmop_ndc_value] - NDC number of the prescription to fetch documentation for
        #
        # @return [documentation] - Drug documentation JSON object from the API
        documentation = client.get_rx_documentation(rx.cmop_ndc_value)
        # Build PrescriptionDocumentation object
        # https://api.krames.com/v3/content/2<ContentType>-<ContentID>
        #
        # @param [documentation] - Drug sheet JSON object from the API
        #
        # @return [prescription_documentation] - PrescriptionDocumentation object with HTML content containing drug information
        prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
        render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
      rescue => e
        render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
      end
    end
  end
end
