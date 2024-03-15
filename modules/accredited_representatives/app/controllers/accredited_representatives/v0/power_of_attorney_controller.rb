# frozen_string_literal: true

module AccreditedRepresentatives
  module V0
    class PowerOfAttorneyController < ApplicationController
      def accept
        render json: { message: 'Accepted' }, status: :ok
      end
    end
  end
end
