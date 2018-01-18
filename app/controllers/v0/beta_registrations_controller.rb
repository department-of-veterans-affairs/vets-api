# frozen_string_literal: true

module V0
  class BetaRegistrationsController < ApplicationController
    def show
      reg = BetaRegistration.find_by(user_uuid: current_user.uuid, feature: params[:feature])
      raise Common::Exceptions::RecordNotFound, current_user.uuid if reg.nil?
      render json: { 'user': current_user.email, 'status': 'OK' }
    end

    def create
      BetaRegistration.find_or_create_by(user_uuid: current_user.uuid, feature: params[:feature])
      render json: { 'user': current_user.email, 'status': 'OK' }
    end
  end
end
