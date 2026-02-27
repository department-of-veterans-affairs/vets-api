# frozen_string_literal: true

require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class IvcChampvaGateway < BaseGateway
        def submissions
          if options[:user_email].blank?
            Rails.logger.info(
              'Skipping IVC CHAMPVA submission status lookup due to missing user email',
              service: 'ivc_champva'
            )
            return []
          end

          IvcChampvaForm.where(email: options[:user_email]).order(created_at: :asc).to_a
        end

        # Status fields are stored directly on IvcChampvaForm rows, so this
        # gateway does not call an external API.
        def api_statuses(_submissions)
          [nil, nil]
        end
      end
    end
  end
end
