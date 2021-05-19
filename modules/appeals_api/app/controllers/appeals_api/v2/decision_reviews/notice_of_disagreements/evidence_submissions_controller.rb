# frozen_string_literal: true

module AppealsApi::V2
  module DecisionReviews
    module NoticeOfDisagreements
      class EvidenceSubmissionsController < AppealsApi::ApplicationController
        skip_before_action :authenticate

        def create
          render json: { message: 'V2 is not implemented yet' }, status: :not_implemented
        end

        def show
          render json: { message: 'V2 is not implemented yet' }, status: :not_implemented
        end
      end
    end
  end
end
