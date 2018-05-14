# frozen_string_literal: true

require 'common/client/base'
require 'mhv_ac/configuration'
require 'mhv_ac/registration_form'
require 'mhv_ac/upgrade_form'

module MHVAC
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration MHVAC::Configuration

    # Disabled because coverage will be below threshold for these.
    # Create an MHV account
    def post_register(params)
      form = MHVAC::RegistrationForm.new(params)
      perform(:post, 'account/register', form.mhv_params, nonauth_headers).body
    end

    # Upgrade an MHV account
    def post_upgrade(params)
      form = MHVAC::UpgradeForm.new(params)
      perform(:post, 'account/upgrade', form.mhv_params, nonauth_headers).body
    end

    # These two lists (state and country) should be cached for any given day.
    # Get a list of available states (used for registration)
    def get_states
      perform(:get, 'enum/states', nil, nonauth_headers).body
    end

    # Get a list of available countries (used for registraion)
    def get_countries
      perform(:get, 'enum/countries', nil, nonauth_headers).body
    end

    private

    def nonauth_headers
      config.base_request_headers.merge('appToken' => config.app_token)
    end
  end
end
