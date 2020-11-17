# frozen_string_literal: true

require 'uri'
require 'vetext/configuration'

module VEText
  # Class used to connect to the VEText service.
  #
  class Service < Common::Client::Base
    configuration VEText::Configuration

    REGISTER_PATH = '/register'
    PREFS_PATH = '/prefs'

    # Register a user's mobile device with the push notification service.
    #
    # @app_sid String the identifier for the Mobile App you are registering with. See Settings.
    # @device_token String the unique token for the user's device
    # @icn String the user's unique id
    # @os_name String the operating system name from the device
    # @os_version String the operating system version number from the device
    # @device_name String (optional) the name of the device
    #
    # @return Hash response object
    #
    def register(app_sid, device_token, icn, os_name, os_version, device_name=nil)
      response = perform(
        :put, REGISTER_PATH, encoded_params(app_sid, device_token, icn, os_name, os_version, device_name), { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Get the user's preferences.
    #
    # @app_sid String the identifier for the Mobile App you are registering with. See Settings.
    # @icn String the user's unique id
    #
    # @return Hash response object
    # 
    def get_prefs(app_sid, icn)
      response = perform(
        :get, PREFS_PATH, {appSid: app_sid, icn: icn}
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    # Save the user's preferences.
    #
    # @app_sid String the identifier for the Mobile App you are registering with. See Settings.
    # @icn String the user's unique id
    # @prefs Hash the user's prefs
    #
    # @return Hash response object
    # 
    def set_prefs(app_sid, icn, prefs)
      encoded_params = URI.encode_www_form(
        {
          appSid: app_sid,
          icn: icn,
          prefs: prefs
        }
      response = perform(
        :put, PREFS_PATH, encoded_params, { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    private

    def encoded_params(app_sid, device_token, icn, os_name, os_version, device_name)
      URI.encode_www_form(
        {
          appSid: app_sid,
          token: device_token,
          icn: icn,
          os: os_name,
          osVersion: os_version,
          deviceName: device_name  || os_name
        }
      )
    end

    def remap_error(e)
      case e.status
      when 400
        raise Common::Exceptions::BackendServiceException.new('VETEXT_400', detail: e.body)
      when 500
        raise Common::Exceptions::BackendServiceException, 'VETEXT_502'
      else
        raise e
      end
    end
  end
end
