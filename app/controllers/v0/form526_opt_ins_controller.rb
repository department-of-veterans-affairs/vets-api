# frozen_string_literal: true

module V0
  class Form526OptInsController < ApplicationController
    before_action { authorize :evss, :access? }

    def create
      opt_in = Form526OptIn.where(user_uuid: current_user.uuid).first_or_initialize
      opt_in.email = params[:email]
      opt_in.save!
      render json: opt_in,
             serializer: Form526OptInSerializer
    end
  end
end
