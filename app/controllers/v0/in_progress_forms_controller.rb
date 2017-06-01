# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    def show
      form_id = params[:id]
      form = InProgressForm.form_for_user(form_id, @current_user)
      result = form ? form.data_and_metadata : FormProfile.new.prefill_form(form_id, @current_user)
      render json: result
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first_or_initialize
      result = form.update(params.permit(:form_data, :metadata))
      raise Common::Exceptions::InternalServerError unless result
      head :ok
    end
  end
end
