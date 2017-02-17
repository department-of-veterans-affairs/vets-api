# frozen_string_literal: true
require 'common/client/base'
require 'mhv_account/configuration'

module MHVAccount
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration MHVAccount::Configuration

    # Create an MHV account
    # def register
    #   form = MHVAccount::RegistrationForm.new(self, params)
    #   raise Common::Exceptions::ValidationErrors, form unless form.valid?
    #   perform(:post, '/register', form.params, token_headers).body
    # end

    # Upgrade an MHV account
    # def upgrade(params)
    #   form = MHVAccount::UpgradeForm.new(self, params)
    #   raise Common::Exceptions::ValidationErrors, form unless form.valid?
    #   perform(:post, '/upgrade', form.params, token_headers).body
    # end

    private

    def token_headers
      {
        'appToken' => config.app_token
      }
    end
  end
end
