# frozen_string_literal: true

module ClaimsApi
  module V2
    class ApplicationController < ::OpenidApplicationController
      include ClaimsApi::HeaderValidation
      include ClaimsApi::JsonFormatValidation

      before_action :validate_json_format, if: -> { request.post? }
    end
  end
end
