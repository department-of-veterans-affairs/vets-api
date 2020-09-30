# frozen_string_literal: true

module HealthQuest
  module V0
    class BaseController < ::ApplicationController
      before_action :authorize

      protected

      def authorize
        raise_access_denied unless current_user.authorize(:health_quest, :access?)
        raise_access_denied_no_icn if current_user.icn.blank?
      end

      def raise_access_denied
        raise Common::Exceptions::Forbidden, detail: 'You do not have access to the health quest service'
      end

      def raise_access_denied_no_icn
        raise Common::Exceptions::Forbidden, detail: 'No patient ICN found'
      end
    end
  end
end
