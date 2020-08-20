# frozen_string_literal: true

module VaForms
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
  end
end
