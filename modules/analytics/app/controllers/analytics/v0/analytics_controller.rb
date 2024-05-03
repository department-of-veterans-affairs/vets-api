module Analytics
  module V0
    class AnalyticsController < ApplicationController
      skip_before_action :authenticate

      def index
        data = { hello: 'world', salt: Settings.analytics.unique_user.salt }
        render json: data
      end
    end
  end
end
