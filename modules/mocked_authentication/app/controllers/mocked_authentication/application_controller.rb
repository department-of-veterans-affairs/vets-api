# frozen_string_literal: true

module MockedAuthentication
  class ApplicationController < ActionController::Base
    include Traceable
    service_tag 'mock-authentication'
  end
end
