# frozen_string_literal: true

module MyHealth
  module V2
    module Prescriptions
      class DrugSheetsController < RxController
        # Search for drug sheet documentation by NDC (National Drug Code).
        # Uses Krames API to fetch drug information HTML content.
        def search
          ndc = params[:ndc]
          return render_ndc_required_error if ndc.blank?

          documentation = client.get_rx_documentation(ndc)
          prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
          render json: MyHealth::V2::DrugSheetSerializer.new(prescription_documentation)
        rescue Common::Exceptions::BackendServiceException => e
          raise e unless e.original_status == 404

          render_not_found_error
        rescue Common::Exceptions::Forbidden
          raise
        rescue => e
          Rails.logger.error(
            "DrugSheetsController: Failed to fetch documentation for NDC #{ndc} - " \
            "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
          )
          render_service_unavailable_error
        end

        private

        def render_ndc_required_error
          render json: { error: { code: 'NDC_REQUIRED', message: 'NDC number is required' } }, status: :bad_request
        end

        def render_not_found_error
          render json: { error: { code: 'DOCUMENTATION_NOT_FOUND', message: 'Documentation not found for this NDC' } },
                 status: :not_found
        end

        def render_service_unavailable_error
          render json: { error: { code: 'SERVICE_UNAVAILABLE', message: 'Unable to fetch documentation' } },
                 status: :service_unavailable
        end
      end
    end
  end
end
