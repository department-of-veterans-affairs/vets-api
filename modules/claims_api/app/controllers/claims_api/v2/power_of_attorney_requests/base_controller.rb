# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      class BaseController < ApplicationController
        include BGSClientErrorHandling
        include JsonValidation
      end
    end
  end
end
