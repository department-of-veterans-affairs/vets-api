# frozen_string_literal: true

require 'common/exceptions'

module VBADocuments
  module V1
    class ReportsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :validate_params

      MAX_REPORT_SIZE = 1000
      ID_PARAM = 'ids'

      def create
        Rails.logger.info "Request from Consumer #{consumer} has #{params[ID_PARAM].size}" \
                          " total GUIDs and the first 5 are #{params[ID_PARAM].first(5)}"
        statuses = VBADocuments::UploadSubmission.where(guid: params[ID_PARAM])
        spoofed_statuses = with_spoofed(statuses)

        options = { params: { render_location: false } }
        render json: VBADocuments::V1::UploadSerializer.new(spoofed_statuses, options)
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

        if params[ID_PARAM].size > MAX_REPORT_SIZE
          raise Common::Exceptions::InvalidFieldValue.new(
            "#{ID_PARAM} (max #{MAX_REPORT_SIZE})",
            "provided #{params[ID_PARAM].size} items"
          )
        end
      end
    end
  end
end
