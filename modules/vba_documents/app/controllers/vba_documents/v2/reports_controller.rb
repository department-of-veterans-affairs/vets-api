# frozen_string_literal: true

require 'common/exceptions'

module VBADocuments
  module V2
    class ReportsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :validate_params

      MAX_REPORT_SIZE = 1000
      ID_PARAM = 'ids'

      def create
        statuses = VBADocuments::UploadSubmission.where(guid: params[ID_PARAM])
        render json: with_spoofed(statuses),
               each_serializer: VBADocuments::V2::UploadSerializer
      end

      private

      def with_spoofed(statuses)
        guids = statuses.map(&:guid)
        missing = params[ID_PARAM] - guids
        statuses.to_a + missing.map { |id| VBADocuments::UploadSubmission.fake_status(id) }
      end

      def validate_params
        raise Common::Exceptions::ParameterMissing, ID_PARAM if params[ID_PARAM].nil?
        raise Common::Exceptions::InvalidFieldValue.new(ID_PARAM, params[ID_PARAM]) unless params[ID_PARAM].is_a?(Array)
        raise Common::Exceptions::InvalidFieldValue.new(ID_PARAM, params[ID_PARAM]) if
          params[ID_PARAM].size > MAX_REPORT_SIZE
      end
    end
  end
end
