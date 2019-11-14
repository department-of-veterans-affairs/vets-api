# frozen_string_literal: true

require_dependency 'va_forms/form_model_swagger'

module VaForms
  module Docs
    class ApiController < ::ApplicationController
      skip_before_action(:authenticate)
      include Swagger::Blocks
    end
  end
end

