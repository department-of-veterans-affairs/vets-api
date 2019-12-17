# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    class VeteranStatusController < ApplicationController
      def index
        render json: { hit_it: 'yep' }
      end
    end
  end
end
