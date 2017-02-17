# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    def show
      id = params[:id]
      form = InProgressForm.form_for_user(id, @current_user)
      if form
        result = form.form_data
      else
        result = FormProfile.new.prefill_form(id, @current_user)
      end
      render json: result
    end

    def update
      form = InProgressForm.first_or_initialize(form_id: params[:id], user_uuid: @current_user.uuid)
      result = form.update(form_data: params[:form_data])
      raise Common::Exceptions::InternalServerError unless result
      head :ok
    end
  end
end
