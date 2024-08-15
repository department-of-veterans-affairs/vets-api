# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

module Forms
  module SubmissionStatuses
    class Dataset
      attr_accessor :submissions, :intake_statuses, :errors

      def submissions?
        @submissions.any?
      end

      def intake_statuses?
        @intake_statuses.any?
      end

      def errors?
        @errors.present?
      end

      def error_status
        @errors.first[:status] if errors?
      end
    end
  end
end
