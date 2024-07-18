# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

module Forms
  module SubmissionStatuses
    class Dataset
      attr_accessor :submissions, :statuses

      def submissions?
        @submissions.any?
      end

      def statuses?
        @statuses.any?
      end
    end
  end
end
