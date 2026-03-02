# frozen_string_literal: true

require 'digital_forms_api/service/forms'
require 'digital_forms_api/service/submissions'

module DigitalFormsApi
  # The Fully Digital Forms controller that handles fetching form submissions and templates
  class SubmissionsController < ApplicationController
    service_tag 'digital-forms'

    before_action :check_flipper_flag

    # Fetch form submission and template from Forms API
    def show
      submission = submissions_service.retrieve(params[:id])
      template = forms_service.template('21-686c')
      render json: { submission: submission.body, template: template.body['formTemplate'] }
    rescue Common::Client::Errors::ClientError => e
      if e.status == 404
        render json: { error: 'Not found' }, status: :not_found
      else
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end
    rescue
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end

    private

    def check_flipper_flag
      raise Common::Exceptions::Forbidden unless Flipper.enabled?(:dependents_digital_forms_api_submission_enabled,
                                                                  current_user)
    end

    # Instantiate service for interacting with the /forms endpoints
    def forms_service
      DigitalFormsApi::Service::Forms.new
    end

    # Instantiate service for interacting with the /submissions endpoints
    def submissions_service
      DigitalFormsApi::Service::Submissions.new
    end
  end
end
