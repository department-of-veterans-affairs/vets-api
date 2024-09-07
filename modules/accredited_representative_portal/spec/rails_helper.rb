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
end

RSpec.configure do |config|
  config.include AccreditedRepresentativePortal::AuthenticationHelper, type: :request
  config.include AccreditedRepresentativePortal::AuthenticationHelper, type: :controller
  config.include AccreditedRepresentativePortal::RequestHelper, type: :request
  config.include ActiveSupport::Testing::TimeHelpers
end
