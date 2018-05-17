# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'

module VBADocuments
  module V0
    class ReportsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :validate_params

      MAX_REPORT_SIZE = 100
      ID_PARAM = 'ids'

      def create
        statuses = VBADocuments::UploadSubmission.refresh_and_get_statuses!(params[ID_PARAM])
        render json: statuses,
               each_serializer: VBADocuments::UploadSerializer
      end

      private

      def validate_params
        raise Common::Exceptions::ParameterMissing, ID_PARAM if params[ID_PARAM].nil?
        raise Common::Exceptions::InvalidFieldValue.new(ID_PARAM, params[ID_PARAM]) unless params[ID_PARAM].is_a?(Array)
        raise Common::Exceptions::InvalidFieldValue.new(ID_PARAM, params[ID_PARAM]) if
          params[ID_PARAM].size > MAX_REPORT_SIZE
      end
    end
  end
end
