module Analytics
  module V0
    class AnalyticsController < ApplicationController
      before_action :authenticate
      def index
        return unless current_user
        render json: {
          user_fingerprint: get_user_fingerprint(current_user.uuid)
        }
      end

      private 

      def get_user_fingerprint(user_property)
        Digest::SHA256.hexdigest("#{Settings.analytics.unique_user.salt}#{user_property}")
      end
    end
  end
end
