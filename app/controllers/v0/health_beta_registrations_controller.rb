# frozen_string_literal: true
module V0
  class HealthBetaRegistrationsController < ApplicationController

    def show
      reg = HealthBetaRegistration.find_by(user_uuid: current_user.uuid)
      raise Common::Exceptions::RecordNotFound, current_user.uuid if reg.nil?
      render json: { 'user': current_user.email, 'status': 'OK' }
    end

    def create
      HealthBetaRegistration.create(user_uuid: current_user.uuid)
      render nothing: true, status: :accepted
    end
  end
end
