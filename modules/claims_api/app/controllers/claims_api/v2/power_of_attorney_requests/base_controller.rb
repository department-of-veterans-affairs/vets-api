# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class BaseController < ApplicationController
        include ExceptionHandling
        include JsonValidation
      end
    end
  end
end
