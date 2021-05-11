# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ApplicationController
      skip_before_action :authenticate, only: %i[show]

      def show
        render json: { icn: '123456789' }
      end
    end
  end
end
