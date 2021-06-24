# frozen_string_literal: true

module CheckIn
  module V0
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        render json: { data: {} }
      end

      def create
        render json: { data: { status: 'checked-in' } }
      end
    end
  end
end
