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

    # Register a user's mobile device with the push notification service.
    #
    # @app_sid String        the identifier specific to the Mobile App
    # @device_token String   the unique token for the user's device
    # @icn String            the user's unique id in MVI
    # @os_name String        the operating system name from the device
    # @os_version String     the operating system version number from the device
    # @device_name String    (optional) the name of the device
    #
    # @return Hash           response object, which includes endpoint_sid
    #
    def register(app_sid, device_token, icn, os_name, os_version, device_name = nil)
      response = perform(
        :put,
        REGISTER_PATH, {
          appSid: app_sid,
          token: device_token,
          icn: icn,
          os: os_name,
          osVersion: os_version,
          deviceName: device_name || os_name
        }
      )
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
        `#{PREFERENCES_PATH}/#{endpoint_sid}`
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Set a single preference for a given user/device.
    #
    # @endpoint_sid String    the registration id as returned from `register`
    # @preference_id String   the preference type identifier
    # @value boolean          true: user wishes to receive this type of push notification
    #
    # @return Hash            response object
    #
    def set_preference(endpoint_sid, preference_id, value)
      response = perform(
        :put,
        PREFERENCES_PATH, {
          endpointSid: endpoint_sid,
          preferenceId: preference_id,
          value: !!value
        }
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    private

    def remap_error(e)
      case e.status
      when 400..499
        raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_400', { detail: e.body[:error] }, e.status, e.body)
      when 500..599
        raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_502', {}, e.status)
      else
        raise e
      end
    end
  end
end
