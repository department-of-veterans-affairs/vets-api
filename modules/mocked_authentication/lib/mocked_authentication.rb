# frozen_string_literal: true

require 'mocked_authentication/version'
require 'mocked_authentication/engine'

module MockedAuthentication
  def self.mockable_env?
    %w[test localhost development staging].include?(Settings.vsp_environment)
  end
end
