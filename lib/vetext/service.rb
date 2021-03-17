# frozen_string_literal: true

require 'vetext/configuration'

module VEText
  # Class used to connect to the VEText service which sends
  # push notifications.
  #
  class Service < Common::Client::Base
    configuration VEText::Configuration

    BASE_PATH = '/api/vetext/pub/mobile/push'
    REGISTER_PATH = BASE_PATH + '/endpoint'
    PREFERENCES_PATH = BASE_PATH + '/preferences/client'
    SEND_PATH = BASE_PATH + '/send'

    def register(app_name, device_token, icn, os_info, device_name = nil)
      perform(:put, REGISTER_PATH, {
                appSid: app_sid(app_name),
                token: device_token,
                icn: icn,
                os: os_info[:name],
                osVersion: os_info[:version],
                deviceName: device_name || os_info[:name]
              })
    end

    def get_preferences(endpoint_sid)
      perform(:get, "#{PREFERENCES_PATH}/#{endpoint_sid}", nil)
    end

    def set_preference(endpoint_sid, preference_id, receive_preference)
      perform(:put, PREFERENCES_PATH, {
                endpointSid: endpoint_sid,
                preferenceId: preference_id,
                value: receive_preference == true
              })
    end

    def send_notification(app_name, icn, template_id, personalization = {})
      perform(:post, SEND_PATH, {
                appSid: app_sid(app_name),
                icn: icn,
                templateSid: template_id,
                personalization: personalization
              })
    end

    private

    def app_sid(app_name)
      settings = Settings.vetext_push
      if settings.key?("#{app_name}_sid".to_sym)
        settings["#{app_name}_sid".to_sym]
      else
        raise Common::Exceptions::RecordNotFound, app_name
      end
    end
  end
end
