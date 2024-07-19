# frozen_string_literal: true

module Vye
  module V1
    class ApplicationController < Vye::ApplicationController
      class FeatureDisabled < StandardError; end

      attr_reader :user_info

      before_action :verify_feature_enabled!
      before_action :load_user_info

      after_action :verify_authorized

      rescue_from FeatureDisabled, with: -> { render json: { error: 'Bad Request' }, status: :bad_request }

      private

      def verify_feature_enabled!
        return true if Flipper.enabled?(:vye_request_allowed)

        raise FeatureDisabled
      end

      def load_user_info
        @user_info = Vye::UserProfile.find_and_update_icn(user: current_user)&.active_user_info
      end
    end
  end
end
