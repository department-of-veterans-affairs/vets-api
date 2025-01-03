class ApplicationController < ActionController::Base
  include Traceable

  after_action :set_csrf_header, if: -> { ActionController::Base.allow_forgery_protection }

  private

  def set_csrf_header
    token = form_authenticity_token
    response.set_header('X-CSRF-Token', token)
  end
end