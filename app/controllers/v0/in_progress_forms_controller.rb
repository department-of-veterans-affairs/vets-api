# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    before_action :check_access_denied

    def index
      render json: InProgressForm.where(user_uuid: @current_user.uuid)
    end

    def show
      form_id = params[:id]
      form = InProgressForm.form_for_user(form_id, @current_user)
      if form
        render json: form.data_and_metadata
      elsif @current_user.can_access_prefill_data?
        render json: FormProfile.for(form_id).prefill(@current_user)
      else
        head 404
      end
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first_or_initialize
      form.update!(form_data: params[:form_data], metadata: params[:metadata])
      render json: form
    end

    def destroy
      form = InProgressForm.form_for_user(params[:id], @current_user)
      raise Common::Exceptions::RecordNotFound, params[:id] unless form.present?
      form.destroy
      render json: form
    end

    private

    def check_access_denied
      return if @current_user.can_save_partial_forms?
      raise Common::Exceptions::Unauthorized, detail: 'You do not have access to save in progress forms'
    end
  end
end
