# frozen_string_literal: true

module Forms
  module SubmissionStatuses
    module Gateways
      # Base class for implementing custom gateways for different Form APIs
      #
      # Example usage for a new Form API:
      #
      # class MyNewGateway < BaseGateway
      #   def submissions
      #     # Query your specific form submission table/model
      #     # Must return array of objects with form submission data
      #   end
      #
      #   def api_statuses(submissions)
      #     # Call your Form API to get status updates
      #     # Must return [statuses_data, errors] format
      #   end
      #
      #   private
      #
      #   def api_service
      #     # Initialize your API service client
      #   end
      # end
      class BaseGateway
        attr_accessor :dataset

        def initialize(user_account:, allowed_forms: nil, **options)
          @user_account = user_account
          @allowed_forms = allowed_forms
          @options = options
          @dataset = Forms::SubmissionStatuses::Dataset.new
          @error_handler = Forms::SubmissionStatuses::ErrorHandler.new
        end

        def data
          @dataset.submissions = submissions
          @dataset.intake_statuses, @dataset.errors = api_statuses(@dataset.submissions) if @dataset.submissions?

          @dataset
        end

        # Override this method in your gateway implementation
        def submissions
          raise NotImplementedError, 'Subclasses must implement #submissions method'
        end

        # Override this method in your gateway implementation
        def api_statuses(submissions)
          raise NotImplementedError, 'Subclasses must implement #api_statuses method'
        end

        protected

        attr_reader :user_account, :allowed_forms, :options, :error_handler
      end
    end
  end
end
