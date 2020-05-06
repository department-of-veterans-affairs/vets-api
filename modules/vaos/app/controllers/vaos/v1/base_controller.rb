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
    class BaseController < ::VAOS::BaseController
      before_action :authorize

      private

      def render_errors(va_exception)
        resource_type = controller_name.singularize.capitalize
        id = params[:id]
        operation_outcome = VAOS::V1::OperationOutcome.new(
          resource_type: resource_type,
          id: id,
          issue: va_exception
        )
        render json: VAOS::V1::OperationOutcomeSerializer.new(operation_outcome).serialized_json
      end
    end
  end
end
