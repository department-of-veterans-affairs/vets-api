# frozen_string_literal: true

require 'datadog'

module BioHeartApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate, if: :skip_authentication?
      before_action :load_user, if: :skip_authentication?
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '21P-0537' => 'vba_21p_0537',
        '21P-601' => 'vba_21p_601'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[21P-0537 21P-601].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        
        # Create a temporary response object to capture the delegation result
        temp_response = ActionDispatch::Response.new
        
        simple_forms_controller = SimpleFormsApi::V1::UploadsController.new
        simple_forms_controller.request = request
        simple_forms_controller.response = temp_response
        simple_forms_controller.params = params
        
        # Perform the action
        simple_forms_controller.submit
        return
      rescue SimpleFormsApi::Exceptions::ScrubbedUploadsSubmitError => e
        # Hack for proof of concept (the concept is bad though, obviously)
        if e.to_s.include?("Render and/or redirect were called multiple times")
          return
        else
          raise e
        end
      rescue => e
        # TODO: add custom error handler like ScrubbedUploadsSubmitError
        raise e
      end

      private 

      def skip_authentication?
        UNAUTHENTICATED_FORMS.include?(params[:form_number]) || UNAUTHENTICATED_FORMS.include?(params[:form_id])
      end
    end

  end
end
