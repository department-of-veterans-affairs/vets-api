# frozen_string_literal: true

# controller that aren't a part of the vets-website backend should use this controller
class ExternalApiApplicationController < ApplicationController
  skip_before_action :validate_csrf_token!
  skip_after_action :set_csrf_cookie
end
