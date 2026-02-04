# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        id = params[:id]
        rx = client.get_rx_details(id)

        raise Common::Exceptions::RecordNotFound, id if rx.nil?

        if rx&.cmop_ndc_value.blank?
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: 'Prescription is missing required drug information (NDC)'
          )
        end

        documentation = client.get_rx_documentation(rx.cmop_ndc_value)
        prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
        render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
      end
    end
  end
end
