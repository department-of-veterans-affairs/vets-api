# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module ClaimsApi
  module V2
    module BenefitsDocuments
      class Service < ::Common::Client::Base
        configuration ClaimsApi::V2::BenefitsDocuments::Configuration

        def get_auth_token
          config.get_access_token
        end
      end
    end
  end
end
