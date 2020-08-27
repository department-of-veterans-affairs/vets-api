# frozen_string_literal: true

module V0
  module DecisionReviews
    module HigherLevelReviews
      class ContestableIssuesController < AppealsBaseController
        def index
          render json: service_response.body, status: service_response.status
        end

        def service_response
          DecisionReview::HigherLevelReview::GetContestablesIssues::Service.new(args).response
        end

        def args
          Struct.new(:headers, :benefit_type).new headers, params[:benefit_type]
        end

        def headers
          {
            'X-VA-SSN' => current_user.ssn,
            'X-VA-Receipt-Date' => Time.zone.now.strftime('%F')
          }
        end
      end
    end
  end
end
