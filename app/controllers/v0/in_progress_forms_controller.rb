# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    before_action :ensure_uuid
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
      result = form.update(form_data: params[:form_data], metadata: params[:metadata])
      raise Common::Exceptions::InternalServerError unless result
      render json: form
    end

    def destroy
      form = InProgressForm.form_for_user(params[:id], @current_user)
      form.destroy
      render json: form
    end

    private

    def ensure_uuid
      # There have been several errors where `@current_user.uuid` is being coerced to `nil`
      # by activerecord. This checks the the `uuid` against the same regex and logs an error
      # if we see a 'malformed' id.
      uuid_format = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid::ACCEPTABLE_UUID
      # We should always have a uuid on @current_user. If this fails, that's another issue
      unless @current_user.uuid.to_s[uuid_format, 0]
        log_message_to_sentry('Invalid UUID for AR/PG', :error, user_uuid: @current_user.uuid,
                                                                session_uuid: @session.uuid)
      end
    end

    def check_access_denied
      return if @current_user.can_save_partial_forms?
      raise Common::Exceptions::Unauthorized, detail: 'You do not have access to save in progress forms'
    end
  end
end
