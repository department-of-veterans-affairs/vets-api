# frozen_string_literal: true

module DigitalFormsApi
  module V0
    class SubmissionsController < ApplicationController
      def show
        response = submissions_service.retrieve(params[:id])

        render json: response.body, status: response.status
      end

      def create
        context = submissions_service.submit_with_context(submission_payload, submission_metadata, dry_run: dry_run?)
        ensure_submission_uuid!(context)

        render json: { data: context }
      end

      private

      def submissions_service
        @submissions_service ||= DigitalFormsApi::Service::Submissions.new
      end

      def submission_payload
        params.require(:payload).to_unsafe_h
      end

      def submission_metadata
        metadata = params.require(:metadata).permit(:formId, :veteranId, :claimantId, :epCode, :claimLabel)
                         .to_h.symbolize_keys

        %i[formId veteranId epCode claimLabel].each do |key|
          raise ActionController::ParameterMissing, key if metadata[key].blank?
        end

        metadata
      end

      def dry_run?
        ActiveModel::Type::Boolean.new.cast(params[:dry_run])
      end

      def ensure_submission_uuid!(context)
        return if context[:submission_uuid].present?

        raise Common::Exceptions::BadGateway.new(detail: 'Digital Forms submission did not return a submission UUID')
      end
    end
  end
end
