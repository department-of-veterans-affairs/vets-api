# frozen_string_literal: true

# Controller for managing user scheduling preferences in VA.gov profile.
# This controller is still under development, with stubbed transaction responses gated
# behind the profile_scheduling_preferences feature flag.

module V0
  module Profile
    class SchedulingPreferencesController < ApplicationController
      before_action { authorize :vet360, :access? }
      before_action :check_feature_flag!
      before_action :check_pilot_access!

      service_tag 'profile'

      def show
        preferences = [
          { item_id: 1, option_ids: [5] },
          { item_id: 2, option_ids: [7, 11] }
        ]

        preferences_data = { preferences: }

        render json: SchedulingPreferencesSerializer.new(preferences_data)
      end

      def create
        transaction_response = build_stub_transaction_response
        render json: transaction_response, status: :ok
      end

      def update
        transaction_response = build_stub_transaction_response
        render json: transaction_response, status: :ok
      end

      def destroy
        transaction_response = build_stub_transaction_response
        render json: transaction_response, status: :ok
      end

      private

      def check_feature_flag!
        unless Flipper.enabled?(:profile_scheduling_preferences, @current_user)
          raise Common::Exceptions::Forbidden, detail: 'Scheduling preferences not available'
        end
      end

      def check_pilot_access!
        visn_service = UserVisnService.new(@current_user)
        unless visn_service.in_pilot_visn?
          Rails.logger.info("Scheduling preferences not available for your facility for user #{@current_user.uuid}")
          raise Common::Exceptions::Forbidden, detail: 'Unable to verify access to scheduling preferences'
        end
      end

      def scheduling_preference_params
        params.permit(:item_id, option_ids: [])
      end

      def build_stub_transaction_response
        {
          data: {
            type: 'async_transaction_va_profile_person_option_transactions',
            id: SecureRandom.uuid,
            attributes: {
              transaction_id: SecureRandom.uuid,
              transaction_status: 'COMPLETED_SUCCESS',
              type: 'AsyncTransaction::VAProfile::PersonOptionTransaction',
              metadata: []
            }
          }
        }
      end
    end
  end
end
