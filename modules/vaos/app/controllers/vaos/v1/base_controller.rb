# frozen_string_literal: true

module VAOS
  module V1
    # Base controller for all FHIR (DSTU 2) resources.
    # Overrides the main ApplicationController's render_errors method
    # to wrap errors in FHIR Operation Outcomes.
    #
    # @example Create a controller for the Organization resource
    #   module VOAS
    #     module V1
    #       class OrganizationsController < BaseController
    #         def index...
    #
    class BaseController < VAOS::BaseController
      before_action :authorize

      private

      def fhir_service
        VAOS::V1::FHIRService.new(
          resource_type: controller_name.capitalize.camelize.singularize.to_sym,
          user: current_user
        )
      end

      def render_errors(va_exception)
        resource_type = controller_name.singularize.capitalize
        id = params[:id]
        operation_outcome = VAOS::V1::OperationOutcome.new(
          resource_type: resource_type,
          id: id,
          issue: va_exception
        )

        serializer = VAOS::V1::OperationOutcomeSerializer.new(operation_outcome)
        render json: serializer.serialized_json, status: va_exception.status_code
      end
    end
  end
end
