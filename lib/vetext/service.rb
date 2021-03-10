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
      app_sid = app_sid(app_name)
      perform(
        :put,
        REGISTER_PATH, {
          appSid: app_sid,
          token: device_token,
          icn: icn,
          os: os_info[:name],
          osVersion: os_info[:version],
          deviceName: device_name || os_info[:name]
        }
      ).body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    def get_preferences(endpoint_sid)
      perform(
        :get,
        "#{PREFERENCES_PATH}/#{endpoint_sid}",
        nil
      ).body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    def set_preference(endpoint_sid, preference_id, receive_preference)
      perform(
        :put,
        PREFERENCES_PATH, {
          endpointSid: endpoint_sid,
          preferenceId: preference_id,
          value: receive_preference == true
        }
      ).body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    def send_notification(endpoint_id, template_id, personalization = {})
      perform(
        :post,
        SEND_PATH, {
          endpointSid: endpoint_id,
          templateSid: template_id,
          personalization: personalization
        }
      ).body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    private

    def remap_error(e)
      case e.status
      when 400..499
        raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_400',
                                                              { detail: e.body[:error] }, e.status,
                                                              e.body)
      when 500..599
        raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_502', {}, e.status)
      else
        raise e
      end
    end

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
