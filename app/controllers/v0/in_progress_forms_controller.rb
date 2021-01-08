# frozen_string_literal: true

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound

    def index
      render json: current_users_in_progress_forms, key_transform: :unaltered
    end

    def show
      form_id = params[:id]
      form    = InProgressForm.form_for_user(form_id, @current_user)

      if form
        render json: form.data_and_metadata
      else
        render json: FormProfile.for(form_id: form_id, user: @current_user).camelized_prefill
      end
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first_or_initialize
      form.update!(form_data: params[:form_data] || params[:formData], metadata: params[:metadata])
      render json: form
    end

    def destroy
      form = InProgressForm.form_for_user(params[:id], @current_user)
      raise Common::Exceptions::RecordNotFound, params[:id] if form.blank?

      form.destroy
      render json: form
    end

    def current_users_in_progress_forms
      InProgressForm.where(user_uuid: @current_user.uuid)
    end
  end
end
