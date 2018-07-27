# frozen_string_literal: true

module V0
  class Form526OptInsController < ApplicationController
    def create
      Form526OptIn.new(user_uuid: current_user.uuid, email: params[:email]).save!
      render json: { 'email': current_user.email, 'status': 'OK' },
             serializer: Form526OptInSerializer
    end
  end
end
