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

    # Register a user's mobile device with the push notification service.
    #
    # @app_name String       unique key for the mobile app
    # @device_token String   the unique token for the user's device
    # @icn String            the Integration Control Number of the Veteran
    # @os_info String        the operating system name from the device
    # @device_name String    (optional) the name of the device
    #
    # @return Hash           response object, which includes endpoint_sid
    #
    def register(app_name, device_token, icn, os_info, device_name = nil)
      app_sid = get_app_sid(app_name)
      response = perform(
        :put,
        REGISTER_PATH, {
          appSid: app_sid,
          token: device_token,
          icn: icn,
          os: os_info[:name],
          osVersion: os_info[:version],
          deviceName: device_name || os_info[:name]
        }
      )
      raise_if_response_error(response.body)
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Get preferences for a given user/device.
    #
    # @endpoint_sid String    the registration id as returned from `register`
    #
    # @return Hash            response object
    #
    def get_preferences(endpoint_sid)
      response = perform(
        :get,
        "#{PREFERENCES_PATH}/#{endpoint_sid}",
        nil
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Set a single preference for a given user/device.
    #
    # @endpoint_sid String          the registration id as returned from `register`
    # @preference_id String         the preference type identifier
    # @receive_preference boolean   true: user wishes to receive this type of push notification
    #
    # @return Hash                  response object
    #
    def set_preference(endpoint_sid, preference_id, receive_preference)
      response = perform(
        :put,
        PREFERENCES_PATH, {
          endpointSid: endpoint_sid,
          preferenceId: preference_id,
          value: receive_preference == true
        }
      )
      raise_if_response_error(response.body)
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Send a push notification to a single device
    #
    # @endpoint_sid String    the registration id as returned from `register`
    # @template_id String     id of the push notification content template
    # @personalisation Hash   data map provided by sender to fill in specified template
    #
    # @return Hash            response object
    #
    def send_notification(endpoint_id, template_id, personalization = {})
      response = perform(
        :post,
        SEND_PATH, {
          endpointSid: endpoint_id,
          templateSid: template_id,
          personalization: personalization
        }
      )
      raise_if_response_error(response.body)
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    private

    # Raise an error if the service returned an error in the
    # body of a 200 response
    #
    def raise_if_response_error(body)
      raise VEText::ResponseError, body if body[:success] == false
    end

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

    def get_app_sid(app_name)
      settings = Settings.vetext_push
      if settings.key?("#{app_name}_sid".to_sym)
        settings["#{app_name}_sid".to_sym]
      else
        raise Common::Exceptions::BackendServiceException, 'VETEXT_PUSH_404'
      end
    end
  end
end
