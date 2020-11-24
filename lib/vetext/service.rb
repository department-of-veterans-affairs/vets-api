# frozen_string_literal: true

require 'vetext/configuration'

module VEText
  # Class used to connect to the VEText service which sends
  # push notifications.
  #
  class Service < Common::Client::Base
    configuration VEText::Configuration

    REGISTER_PATH = '/api/vetext/pub/mobile/push/endpoint'

    # Register a user's mobile device with the push notification service.
    #
    # @app_sid String        the identifier specific to the Mobile App
    # @device_token String   the unique token for the user's device
    # @icn String            the user's unique id in MVI
    # @os_name String        the operating system name from the device
    # @os_version String     the operating system version number from the device
    # @device_name String    (optional) the name of the device
    #
    # @return Hash           response object, which includes sid
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

    private

    def remap_error(e)
      case e.status
      when 400..499
        raise Common::Exceptions::BackendServiceException.new('VETEXT_400', { detail: e.body[:error] }, e.status, e.body)
      when 500..599
        raise Common::Exceptions::BackendServiceException.new('VETEXT_502', {}, e.status)
      else
        raise e
      end
    end
  end
end
