# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'

module VBADocuments
  module V0
    class ReportsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :validate_params

      MAX_REPORT_SIZE = 100

      def create
        statuses = VBADocuments::UploadSubmission.refresh_and_get_statuses!(params['uuids'])
        render json: statuses,
               each_serializer: VBADocuments::UploadSerializer
      end

      def validate_params
        raise Common::Exceptions::ParameterMissing, 'uuids' if params['uuids'].nil?
        raise Common::Exceptions::InvalidFieldValue.new('uuids', params['uuids']) unless params['uuids'].is_a?(Array)
        raise Common::Exceptions::InvalidFieldValue.new('uuids', params['uuids']) if
          params['uuids'].size > MAX_REPORT_SIZE
      end
    end
  end
end
