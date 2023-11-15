# frozen_string_literal: true

module SignIn
  class ServiceAccountController < SignIn::ApplicationController
    skip_before_action :authenticate
    before_action :authenticate_service_account
  end
end
