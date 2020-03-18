# frozen_string_literal: true

# controllers that aren't a part of the vets-website backend should inherit from this controller
class ExternalApiApplicationController < ApplicationController
  skip_before_action :validate_csrf_token!
  skip_after_action :set_csrf_cookie
end
