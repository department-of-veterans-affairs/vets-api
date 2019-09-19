# frozen_string_literal: true

require_dependency 'claims_api/form_526_model_swagger'
require_dependency 'claims_api/form_0966_model_swagger'
require_dependency 'claims_api/form_2122_model_swagger'

module ClaimsApi
  module Docs
    class ApiController < ::ApplicationController
      skip_before_action(:authenticate)
      include Swagger::Blocks
    end
  end
end
