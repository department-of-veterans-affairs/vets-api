# frozen_string_literal: true
module V0
  class FormsController < ApplicationController
    def show
      form = SerializedForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first
      render json: form.form_data
    end

    def update
      head :ok
    end
  end
end
