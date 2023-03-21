# frozen_string_literal: true

require 'vetext/configuration'

module VEText
  # Class used to connect to the VEText service which sends
  # push notifications.
  #
  class Service < Common::Client::Base
    configuration VEText::Configuration

    STATSD_KEY_PREFIX = 'vetext_push'
    BASE_PATH = '/api/vetext/pub/mobile/push'
    REGISTER_PATH = "#{BASE_PATH}/endpoint".freeze
    PREFERENCES_PATH = "#{BASE_PATH}/preferences/client".freeze
    SEND_PATH = "#{BASE_PATH}/send".freeze

    def register(app_name, device_token, icn, os, device_name = nil)
      Rails.logger.info('VEText Push service register method enter', app_name: app_name, app_sid: app_sid(app_name))
      perform(:put, REGISTER_PATH, {
                appSid: app_sid(app_name),
                token: device_token,
                icn: icn,
                os: os,
                deviceName: device_name || os
              })
    end

    def get_preferences(endpoint_sid)
      Rails.logger.info('VEText Push service get prefs method enter', endpoint_sid: endpoint_sid)
      perform(:get, "#{PREFERENCES_PATH}/#{endpoint_sid}", nil)
    end

    def set_preference(endpoint_sid, preference_id, receive_preference)
      Rails.logger.info('VEText Push service set pref method enter', endpoint_sid: endpoint_sid,
                                                                     preference_id: preference_id,
                                                                     receive_preference: receive_preference)
      perform(:put, PREFERENCES_PATH, {
                endpointSid: endpoint_sid,
                preferenceId: preference_id,
                value: receive_preference == true
              })
    end

    def send_notification(app_name, icn, template_id, personalization = {})
      Rails.logger.info('VEText Push service send notification method enter', app_name: app_name,
                                                                              template_id: template_id, icn: icn)
      perform(:post, SEND_PATH, {
                appSid: app_sid(app_name),
                icn: icn,
                templateSid: template_id,
                personalization: format_personalization(personalization)
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

    def format_personalization(personalization)
      formatted_personalization = {}
      personalization.each do |k, v|
        formatted_personalization[k.upcase] = v
      end
      formatted_personalization
    end
  end
end
