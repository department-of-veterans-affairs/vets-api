# frozen_string_literal: true

module ClaimsApi
  module V2
    class ApplicationController < ::OpenidApplicationController
      include ClaimsApi::HeaderValidation
    end
  end
end
