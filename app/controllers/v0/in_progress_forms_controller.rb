# frozen_string_literal: true

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound
    # before_action

    def index
      render json: InProgressForm.where(user_uuid: @current_user.uuid)
    end

    def show
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
      # if user.birls_id missing, user.participant_id missing
      #   call user.mvi_add_person
      # if user.participant_id is missing
      #   call user.mvi_add_person
      # if user.birls_id missing, user.participant_id exists
      #   raise error
    end

    # TO DO:
    # - [ ] tests
    #   - [ ] mvi_add_person in spec/models/mvi_spec.rb
    #     - [ ] update: with a successful add... expect_any_instance_of(Mvi).to receive(:destroy).once will fail after new :delete method is added
    #     - [ ] new: with a failed add... for form '526' expect not to call :delete (instead of :destroy)
    #     - [ ] new: test of :delete method
    #   - [ ] add proxy_add test to spec/models/in_progress_form_spec.rb
    # - [ ] redis_store add :delete method (can not use :destroy bc we don't want to freeze)
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
