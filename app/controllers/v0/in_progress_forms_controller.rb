# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    def show
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first
      raise Common::Exceptions::RecordNotFound, params[:id] unless form
      render json: form.form_data
    end

    def update
      form = InProgressForm.first_or_initialize(form_id: params[:id], user_uuid: @current_user.uuid)
      result = form.update(form_data: params[:form_data])
      raise Common::Exceptions::InternalServerError unless result
      head :ok
    end
  end
end
