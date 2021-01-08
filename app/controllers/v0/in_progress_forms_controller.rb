# frozen_string_literal: true

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound

    def index
      # :unaltered prevents the keys from being deeply transformed, which might corrupt some keys
      # see https://github.com/department-of-veterans-affairs/va.gov-team/issues/17595 for more details
      render json: InProgressForm.where(user_uuid: @current_user.uuid), key_transform: :unaltered
    end

    def show
      form_id = params[:id]
      form    = InProgressForm.form_for_user(form_id, @current_user)

      if form
        render json: form.data_and_metadata
      else
        render json: camelized_prefill_for_current_user
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

    private

    # the front end is always expecting camelCase
    # --this ensures that, even if the OliveBranch inflection header isn't used, camelCase keys are sent
    def camelized_prefill_for_current_user
      # camelize exactly as OliveBranch would
      # inspired by vets-api/blob/327b26c76ea7904744014ea35463022e8b50f3fb/lib/tasks/support/schema_camelizer.rb#L27
      OliveBranch::Transformations.transform(
        FormProfile.for(form_id: params[:id], user: @current_user).prefill.as_json,
        OliveBranch::Transformations.method(:camelize)
      )
    end
  end
end
