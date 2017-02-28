# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    def show
      form_id = params[:id]
      form = InProgressForm.form_for_user(form_id, @current_user)
      result = form ? form.form_data : FormProfile.new.prefill_form(form_id, @current_user)
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
