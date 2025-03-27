# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class IntentToFileController < ApplicationController
      INTENT_TO_FILE_TYPES = %w[compensation pension survivor].freeze

      before_action :check_feature_toggle
      before_action { authorize params[:id], policy_class: IntentToFilePolicy }
      before_action :validate_file_type, only: %i[show create]

      def show
        parsed_response = service.get_intent_to_file(params[:type])

        if parsed_response['errors']&.first.try(:[], 'title') == 'Resource not found'
          raise NotFound.new(error: parsed_response['errors']&.first&.[]('detail'))
        else
          render json: parsed_response, status: :ok
        end
      end

      def create
        parsed_response = service.create_intent_to_file(params[:type], params[:claimant_ssn])

        if parsed_response['errors'].present?
          raise ActionController::BadRequest.new(error: parsed_response['errors']&.first&.[]('detail'))
        else
          render json: parsed_response, status: :created
        end
      rescue ArgumentError => e
        render json: { error: e.message }, status: :bad_request
      end

      private

      def check_feature_toggle
        unless Flipper.enabled?(:accredited_representative_portal_intent_to_file_api, @current_user)
          message = 'The accredited_representative_portal_intent_to_file_api feature flag is disabled ' \
                    "for the user with uuid: #{@current_user.uuid}"

          raise Common::Exceptions::Forbidden, detail: message
        end
      end

      def service
        @service ||= BenefitsClaims::Service.new(params[:id])
      end

      def validate_file_type
        unless INTENT_TO_FILE_TYPES.include? params[:type]
          raise ActionController::BadRequest, <<~MSG.squish
            Invalid type parameter.
            Must be one of (#{INTENT_TO_FILE_TYPES.join(', ')})
          MSG
        end
      end
    end
  end
end
