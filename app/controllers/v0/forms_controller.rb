# frozen_string_literal: true
module V0
  class FormsController < ApplicationController
    def show
      form = SerializedForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first
      raise Common::Exceptions::RecordNotFound.new(params[:id]) unless form
      render json: form.form_data
    end

    def update
      form = SerializedForm.first_or_initialize(form_id: params[:id], user_uuid: @current_user.uuid)
      form.update(form_data: params[:form_data])
      head :ok
    end
  end
end
