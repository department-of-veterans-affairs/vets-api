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
    def post_register
      form = MHVAC::RegistrationForm.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      perform(:post, 'account/register', form.params, auth_headers).body
    end

    # Upgrade an MHV account
    def post_upgrade(params)
      form = MHVAC::UpgradeForm.new(self, params)
      raise Common::Exceptions::ValidationErrors, form unless form.valid?
      perform(:post, 'account/upgrade', form.params, auth_headers).body
    end

    # These two lists (state and country) should be cached for any given day.
    # Get a list of available states (used for registration)
    def get_states
      perform(:get, 'enum/states', nil, auth_headers)
    end

    # Get a list of available countries (used for registraion)
    def get_countries
      perform(:get, 'enum/countries', nil, auth_headers)
    end

    # Account Management (These all require token headers from user session)
    # Current Email Account that receives notifications
    def get_notification_email_address
      perform(:get, 'notification/email', nil, token_headers)
    end

    # Change Email Account that receives notifications
    def post_notification_email_address(params)
      perform(:post, 'notification/email', params, token_headers)
    end

    # Current Rx notification setting
    def get_rx_notification_flag
      perform(:get, 'notification/rx', nil, token_headers)
    end

    # Change Rx notification setting
    def post_rx_notification_flag(flag)
      perform(:post, 'notification/rx', flag: flag, token_headers)
    end

    # Current Appointments notification setting
    def get_appt_notification_flag
      perform(:get, 'notification/appt', nil, token_headers)
    end

    # Change Appointsments notification setting
    def post_appt_notification_flag(flag)
      perform(:post, 'notification/appt', flag: flag, token_headers)
    end
  end
end
