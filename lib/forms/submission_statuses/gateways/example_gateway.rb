# frozen_string_literal: true

# Example implementation for teams adding new Form APIs
# This is a template showing how to implement a gateway for a new Form API.
# Replace "Example" with your actual service name and implement the required methods.
#
# To add this gateway to the system:
# 1. Create your gateway class inheriting from BaseGateway
# 2. Create your formatter class inheriting from BaseFormatter
# 3. Add both to the Report class configuration
# 4. Test your implementation

require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class ExampleGateway < BaseGateway
        def submissions
          # TODO: Implement submission query for your form API
          # Example:
          # query = YourFormSubmission.where(user_account_id: user_account.id)
          # query = query.where(form_type: allowed_forms) if allowed_forms.present?
          # query.order(:created_at).to_a

          raise NotImplementedError, 'Implement submission query for your Form API'
        end

        def api_statuses(submissions)
          # TODO: Implement API call to get statuses
          # Must return [statuses_data, errors] format
          # Example:
          # ids = submissions.map(&:your_id_field)
          # response = your_api_service.get_statuses(ids)
          # [response.data, nil]

          raise NotImplementedError, 'Implement API status retrieval for your Form API'
        end

        # TODO: Add any private helper methods your gateway needs
        # Example:
        # private
        # def your_api_service
        #   @service ||= YourApi::Service.new
        # end
      end
    end
  end
end
