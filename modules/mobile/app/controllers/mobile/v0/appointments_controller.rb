# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        head(:ok)
      end
    end
  end
end
