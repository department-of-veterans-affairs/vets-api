# frozen_string_literal: true

require 'digital_forms_api/service/forms'
require 'digital_forms_api/service/submissions'

module DigitalFormsApi
  class SubmissionsController < ApplicationController
    service_tag 'digital-forms'

    def show
      check_flipper_flag
      begin
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
    end

    private

    def check_flipper_flag
      raise Common::Exceptions::Forbidden unless Flipper.enabled?(:dependents_digital_forms_api_submission_enabled,
                                                                  current_user)
    end

    def forms_service
      DigitalFormsApi::Service::Forms.new
    end

    def submissions_service
      DigitalFormsApi::Service::Submissions.new
    end
  end
end
