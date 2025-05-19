module V0
  class BenefitsSuggestionsController < ApplicationController
    rescue_from ArgumentError, with: :handle_argument_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    
    skip_before_action(:authenticate, only: %i[create])
    skip_before_action :verify_authenticity_token

    rescue_from JSON::ParserError, with: :handle_json_parser_error


    def create
      service = FormEligibility::FormConnectorService.new # This service name might also be a candidate for renaming later if desired
      completed_form_id = params.require(:completed_form_id)
      
      submitted_data_params = params.fetch(:submitted_data, ActionController::Parameters.new({}))
      submitted_data = submitted_data_params.permit!.to_h 

      suggestions = service.suggest_forms(completed_form_id, submitted_data)
      # The key in the JSON response might also be a candidate for renaming, e.g., from { suggestions: ... } to { benefit_suggestions: ... }
      render json: { suggestions: suggestions }, status: :ok
    end

    private

    def handle_argument_error(exception)
      render json: { errors: [{ title: 'Argument Error', detail: exception.message }] }, status: :bad_request
    end

    def handle_parameter_missing(exception)
      render json: { errors: [{ title: 'Parameter Missing', detail: exception.message }] }, status: :bad_request
    end

    def handle_json_parser_error(exception)
      logger.error "JSON Parser Error: #{exception.message}"
      logger.error "Request Body: #{request.raw_post}" # Log the raw body for inspection
      render json: { errors: [{ title: 'Invalid JSON', detail: "There was an error parsing the JSON request body: #{exception.message}" }] }, status: :bad_request
    end
  end
end 
