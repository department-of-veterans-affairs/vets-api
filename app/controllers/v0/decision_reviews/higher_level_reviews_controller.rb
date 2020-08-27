# frozen_string_literal: true

module V0
  module DecisionReviews
    class HigherLevelReviewsController < AppealsBaseController
      def create
        render json: create_service_response.body, status: create_service_response.status
      end

      def show
        render json: show_service_response.body, status: show_service_response.status
      end

      private

      def show_service_response
        DecisionReview::HigherLevelReview::Show::Service.new(show_args).response
      end

      def show_args
        Struct.new(:uuid).new params[:uuid]
      end

      def create_service_response
        DecisionReview::HigherLevelReview::Create::Service.new(create_args).response
      end

      def create_args
        Struct.new(:headers, :body).new create_headers, create_body
      end

      def create_headers
        {
          'X-VA-SSN' => current_user.ssn,
          'X-VA-First-Name' => current_user.first_name,
          'X-VA-Middle-Initial' => current_user.middle_name.presence&.first,
          'X-VA-Last-Name' => current_user.last_name,
          'X-VA-Birth-Date' => current_user.birth_date,
          'X-VA-File-Number' => nil,
          'X-VA-Service-Number' => nil,
          'X-VA-Insurance-Policy-Number' => nil
        }.compact
      end

      def create_body
        { data: params[:data] }
      end
    end
  end
end
