# frozen_string_literal: true

require 'datadog'

module BioHeartApi
  module V1
    class UploadsController < ::SimpleFormsApi::V1::UploadsController
      def submit
        super
        # TODO: after calling super and confirming no errors were thrown in
        # the main PDF generation/submission process, we can kick off whatever
        # needs to happen for the MMS submission.
      end
    end
  end
end
