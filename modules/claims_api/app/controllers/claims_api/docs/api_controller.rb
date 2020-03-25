# frozen_string_literal: true

require_dependency 'claims_api/forms/form_526_response_swagger'
require_dependency 'claims_api/forms/form_0966_response_swagger'
require_dependency 'claims_api/forms/form_2122_response_swagger'

module ClaimsApi
  module Docs
    class ApiController < ::ApplicationController
      skip_before_action(:authenticate)
      include Swagger::Blocks
    end
  end
end
