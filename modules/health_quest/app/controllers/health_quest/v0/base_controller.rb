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

      def log_info
        user_hash = {
          user_uuid: current_user&.uuid,
          user_icn: current_user&.icn,
          loa: current_user&.loa,
          facilities: current_user&.vha_facility_ids,
          controller_name: controller_name,
          controller_action: action_name,
          request_info: {
            id: request&.request_id, ip: request&.remote_ip, method: request&.method, path: request&.fullpath
          },
          session_info: session&.to_h
        }

        Rails.logger.info("User from Loma Linda info: #{user_hash}.")
      end
    end
  end
end
