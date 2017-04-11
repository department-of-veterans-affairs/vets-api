# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'mhv_ac/configuration'
require 'mhv_ac/registration_form'
require 'mhv_ac/upgrade_form'
require 'rx/client_session'

module MHVAC
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration MHVAC::Configuration
    client_session Rx::ClientSession

    # Create an MHV account
    def post_register(params)
      form = MHVAC::RegistrationForm.new(params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      perform(:post, 'account/register', form.params, nonauth_headers).body
    end

    # Upgrade an MHV account
    def post_upgrade(params)
      form = MHVAC::UpgradeForm.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      perform(:post, 'account/upgrade', form.params, token_headers).body
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

    # Account Management (These all require token headers from user session)
    # Current Email Account that receives preferences
    def get_notification_email_address
      perform(:get, 'preferences/email', nil, token_headers).body
    end

    # Change Email Account that receives preferences
    def post_notification_email_address(params)
      perform(:post, 'preferences/email', params, token_headers)
    end

    # Current Rx preference setting
    def get_rx_preference_flag
      perform(:get, 'preferences/rx', nil, token_headers).body
    end

    # Change Rx preference setting
    def post_rx_preference_flag(flag)
      params = { flag: flag }
      perform(:post, 'preferences/rx', params, token_headers)
    end

    # Current Appointments preference setting
    def get_appt_preference_flag
      perform(:get, 'preferences/appt', nil, token_headers).body
    end

    # Change Appointsments preference setting
    def post_appt_preference_flag(flag)
      params = { flag: flag }
      perform(:post, 'preferences/appt', params, token_headers)
    end
  end
end
