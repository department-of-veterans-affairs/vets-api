# frozen_string_literal: true

require 'common/client/base'
require 'mhv_ac/configuration'
require 'mhv_ac/registration_form'
require 'mhv_ac/upgrade_form'

module MHVAC
  ##
  # Core class responsible for MHVAC API interface operations
  #
  class Client < Common::Client::Base
    configuration MHVAC::Configuration

    ##
    # Create an MHV account
    # @param params [Hash] A hash of user parameters
    # @return [Hash] an object containing the body of the response
    #
    def post_register(params)
      form = MHVAC::RegistrationForm.new(params)
      path = 'usermgmt/alter/register'
      perform(:post, path, form.mhv_params, nonauth_headers).body
    end

    ##
    # Upgrade an MHV account
    # @param params [Hash] A hash of user parameters
    # @return [Hash] an object containing the body of the response
    #
    def post_upgrade(params)
      form = MHVAC::UpgradeForm.new(params)
      path = 'usermgmt/alter/upgrade'
      perform(:post, path, form.mhv_params, nonauth_headers).body
    end

    ##
    # Get a list of available states (used for registration)
    # @note These two lists (state and country) should be cached for any given day
    # @return [Hash] an object containing the body of the response
    #
    def get_states
      path = 'usermgmt/enum/states'
      perform(:get, path, nil, nonauth_headers).body
    end

    ##
    # Get a list of available countries (used for registration)
    # @note These two lists (state and country) should be cached for any given day.
    # @return [Hash] an object containing the body of the response
    #
    def get_countries
      path = 'usermgmt/enum/countries'
      perform(:get, path, nil, nonauth_headers).body
    end

    private

    def nonauth_headers
      headers = config.base_request_headers.merge('appToken' => config.app_token)
      get_headers(headers)
    end

    def get_headers(headers)
      headers = headers.dup
      headers.merge('x-api-key' => config.x_api_key)
    end
  end
end
