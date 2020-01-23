# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        appeals_response = Appeals::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        log_response(appeals_response)
        render(
          json: appeals_response.body
        )
      end

      def show_higher_level_review
        higher_level_review = review_service.get_higher_level_reviews(params[:uuid])
        render json: higher_level_review.body
      end

      def show_intake_status
        intake_status = review_service.get_higher_level_reviews_intake_status(params[:intake_id])
        render json: intake_status.body
      end

      def create_higher_level_review
        review = review_service.post_higher_level_reviews(request.raw_post)
        render status: review.status, json: review.body
      end

      def healthcheck
        render json: Appeals::Service.new.healthcheck.body
      end

      private

      def log_request
        hashed_ssn = Digest::SHA2.hexdigest ssn
        Rails.logger.info('Caseflow Request',
                          'va_user' => requesting_va_user,
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body.dig('data', 0, 'id')
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'va_user' => requesting_va_user,
                          'first_appeal_id' => first_appeal_id,
                          'appeal_count' => count)
      end

      def consumer
        request.headers['X-Consumer-Username']
      end

      def ssn
        header('X-VA-SSN')
      end

      def requesting_va_user
        header('X-VA-User')
      end

      def header(key)
        value = request.headers[key]
        raise Common::Exceptions::ParameterMissing, key unless value

        value
      end

      def target_veteran
        OpenStruct.new(ssn: ssn)
      end

      def review_service
        DecisionReview::Service.new
      end
    end
  end
end
