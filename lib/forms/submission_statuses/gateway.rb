# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require_relative 'dataset'

module Forms
  module SubmissionStatuses
    class Gateway
      attr_accessor :dataset

      def initialize(user_account)
        @user_account = user_account
        @dataset = Forms::SubmissionStatuses::Dataset.new
      end

      def fetch_data
        @dataset.submissions = fetch_submissions
        @dataset.statuses = fetch_statuses(@dataset.submissions) if @dataset.submissions?
        @dataset
      end

      def fetch_submissions
        FormSubmission.where(user_account: @user_account).to_a
      end

      def fetch_statuses(submissions)
        uuids = submissions.map(&:benefits_intake_uuid)

        response = benefits_intake_service.bulk_status(uuids:)
        raise response.body unless response.success?

        response.body['data']
      end

      private

      def benefits_intake_service
        @service ||= BenefitsIntake::Service.new
      end
    end
  end
end
