# frozen_string_literal: true

require 'rails_helper'
require_relative 'spec_helper'

require File.expand_path('../../../config/environment', __dir__)

module AccreditedRepresentativePortal
  module RequestHelper
    def parsed_response
      JSON.parse(response.body)
    end
  end

  module AuthenticationHelper
    def login_as(representative_user, options = {})
      options[:access_token] ||=
        create(
          :access_token,
          user_uuid: representative_user.uuid,
          audience: ['arp']
        )

      cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] =
        SignIn::AccessTokenJwtEncoder.new(**options.slice(:access_token)).perform
    end
  end

  module TransientErrorHelper
    def mock_timeout_error
      lh_config = double
      allow(Common::Client::Base).to receive(:configuration).and_return(lh_config)
      allow(lh_config).to receive(:post).and_raise(Faraday::TimeoutError.new('Connection timed out'))
    end

    def mock_404_response
      cassette = double(name: '404_response')
      allow(::VCR).to receive(:current_cassette).and_return(cassette)
      allow(cassette).to receive(:name).and_return('404_response')

      lh_config = double
      allow(Common::Client::Base).to receive(:configuration).and_return(lh_config)
      allow(lh_config).to receive(:post).and_raise(
        Common::Exceptions::ResourceNotFound.new(detail: 'The requested resource could not be found')
      )
    end
  end
end

RSpec.configure do |config|
  config.include AccreditedRepresentativePortal::AuthenticationHelper, type: :request
  config.include AccreditedRepresentativePortal::AuthenticationHelper, type: :controller
  config.include AccreditedRepresentativePortal::RequestHelper, type: :request
  config.include AccreditedRepresentativePortal::TransientErrorHelper
end
