# frozen_string_literal: true

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound

    def index
      render json: InProgressForm.for_user(@current_user)
      # render json: InProgressForm.where(user_uuid: @current_user.uuid)
    end

    def show
      form_id = params[:id]
      form    = InProgressForm.for_user(@current_user).where(form_id: form_id).first

      if form
        render json: form.data_and_metadata
      else
        render json: FormProfile.for(form_id).prefill(@current_user)
      end
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first
      alt_id = InProgressForm.ACCT_ID_PREFIX + @current_user.account_id
      form ||= InProgressForm.where(form_id: params[:id],
                                    user_uuid: alt_id).first_or_initialize
      form.update!(form_data: params[:form_data], metadata: params[:metadata])
      render json: form
    end

    def destroy
      form = InProgressForm.for_user(@current_user).where(form_id: params[:id]).first
      raise Common::Exceptions::RecordNotFound, params[:id] if form.blank?

      form.destroy
      render json: form
    end
  end
end
