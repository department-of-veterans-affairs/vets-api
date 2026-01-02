# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        id = params[:id]
        rx = client.get_rx_details(id)
        raise StandardError, 'Rx not found' if rx.nil?
        raise StandardError, 'Missing NDC number' if rx.cmop_ndc_value.nil?

        # Fetch prescription documentation using the NDC number
        # https://api.krames.com/v3/content/search?ndc=<NDC>
        #
        # Drug documentation JSON object from the API
        documentation = client.get_rx_documentation(rx.cmop_ndc_value)
        # Build PrescriptionDocumentation object
        # https://api.krames.com/v3/content/<ContentType>-<ContentID>
        #
        # PrescriptionDocumentation object with HTML content containing drug information
        prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
        render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
      rescue => e
        render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
      end
    end
  end
end
