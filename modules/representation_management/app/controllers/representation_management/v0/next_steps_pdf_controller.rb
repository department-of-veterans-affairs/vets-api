# frozen_string_literal: true

module RepresentationManagement
  module V0
    class NextStepsPdfController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled
      def create
        data = RepresentationManagement::NextStepsPdfData.new(next_step_pdf_params)

        if data.valid?
          Tempfile.create do |tempfile|
            tempfile.binmode
            RepresentationManagement::V0::PdfConstructor::NextSteps.new(tempfile).construct(form)
            send_data tempfile.read,
                      filename: 'next_steps.pdf',
                      type: 'application/pdf',
                      disposition: 'attachment',
                      status: :ok
          end
          # The Tempfile is automatically deleted after the block ends
        else
          render json: { errors: data.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:use_veteran_models_for_appoint)
      end

      def next_step_pdf_params
        params.require(:next_steps_pdf).permit(:representative_id, :organization_id)
      end
    end
  end
end
