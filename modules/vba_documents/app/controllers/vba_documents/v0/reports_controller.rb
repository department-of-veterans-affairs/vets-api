# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'

module VBADocuments
  module V0
    class ReportsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :validate_params

      MAX_REPORT_SIZE = 100

      def create
        statuses = VBADocuments::UploadSubmission.refresh_and_get_statuses!(params['guids'])
        render json: statuses,
               each_serializer: VBADocuments::UploadSerializer
      end

      private

      def validate_params
        raise Common::Exceptions::ParameterMissing, 'guids' if params['guids'].nil?
        raise Common::Exceptions::InvalidFieldValue.new('guiids', params['guids']) unless params['guids'].is_a?(Array)
        raise Common::Exceptions::InvalidFieldValue.new('guids', params['guids']) if
          params['guids'].size > MAX_REPORT_SIZE
      end
    end
  end
end
