# frozen_string_literal: true

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound
    # before_action

    def index
      render json: InProgressForm.where(user_uuid: @current_user.uuid)
    end

    def show
      proxy_add
      form_id = params[:id]
      form    = InProgressForm.form_for_user(form_id, @current_user)

      if form
        render json: form.data_and_metadata
      else
        render json: FormProfile.for(form_id).prefill(@current_user)
      end
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first_or_initialize
      form.update!(form_data: params[:form_data], metadata: params[:metadata])
      render json: form
    end

    def destroy
      form = InProgressForm.form_for_user(params[:id], @current_user)
      raise Common::Exceptions::RecordNotFound, params[:id] if form.blank?

      form.destroy
      render json: form
    end

    # MVI wants add calls only if from 526 is being completed and user is missing ids
    def proxy_add
      # if user.participant_id
      #   raise Common::Exceptions::ValidationErrors, "Missing birls_id while participant_id present" unless user.birls_id.nil?
      # else
      #   user.mvi_add_person
      # end
    end

    # TO DO:
    # - [ ] tests
    #   - [x] mvi_add_person in spec/models/mvi_spec.rb
    #     - [x] update: with a successful add... expect_any_instance_of(Mvi).to receive(:destroy).once will fail after new :clear_cache method is added
    #     - [x] new: with a failed add... for form '526' expect not to call :clear_cache (instead of :destroy)
    #     - [x] new: test of :clear_cache method
    #   - [x] add proxy_add test to spec/request/in_progress_forms_request_spec.rb
    # - [x] redis_store add :clear_cache method (can not use :destroy bc we don't want to freeze)
    # - [ ] new before_action:
    #   - only on 'show' method
    #   - can we add conditional to check params[:id] == '526' here? we might not have access to params
    # - [ ] new proxy_add method
    #   - we must have those ids in auth headers or EVSS (the submission receiver) will error
    #   - mvi_add_person integration already exists
    # - [ ] swagger docs - update the GET method description to let users know that proxy_add will be called in this case
    # - ~routes.rb update~ does not need to be updated because this is not it's own route)
  end
end
