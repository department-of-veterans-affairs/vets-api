# frozen_string_literal: true

module ClaimsApi
  module Docs
    class ApiController < ::ApplicationController
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      skip_before_action(:authenticate)
      include Swagger::Blocks
    end
  end
end
