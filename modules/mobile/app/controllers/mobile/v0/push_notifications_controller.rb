# frozen_string_literal: true

require 'vetext/service'

module Mobile
  module V0
    class PushNotificationsController < ApplicationController
      def register
        result = service.register(
          params[:app_name],
          params[:device_token],
          @current_user.icn,
          params[:os_name],
          params[:device_name] || params[:osName]
        )

        Rails.logger.info('VEText Push service register success', app_name: params[:app_name])
        render json: Mobile::V0::PushRegisterSerializer.new(params[:app_name], result.body[:sid])
      end

      def get_prefs
        results = service.get_preferences(params[:endpoint_sid])
        Rails.logger.info('VEText Push service get preferences success', endpoint_sid: params[:endpoint_sid])
        render json: Mobile::V0::PushGetPrefsSerializer.new(params[:endpoint_sid], results.body)
      end

      def set_pref
        service.set_preference(params[:endpoint_sid], params[:preference], params[:enabled].to_s.downcase == 'true')

        Rails.logger.info('VEText Push service set preference success', endpoint_sid: params[:endpoint_sid],
                                                                        preference: params[:preference],
                                                                        value: params[:enabled])
        render json: {}, status: :ok
      end

      def send_notification
        service.send_notification(params[:app_name], @current_user.icn, params[:template_id], params[:personalization])

        Rails.logger.info('VEText Push service send success', app_name: params[:app_name],
                                                              template_id: params[:template_id])
        render json: {}, status: :ok
      end

      private

      def service
        @service ||= VEText::Service.new
      end
    end
  end
end
