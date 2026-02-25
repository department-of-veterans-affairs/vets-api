# frozen_string_literal: true

# InProgressFormsController - Handles saving and retrieving in-progress form data
#
# This controller manages the REST API for in-progress forms, allowing users to:
# - List all their in-progress forms (index)
# - Retrieve a specific form with prefilled data (show)
# - Save form progress (update)
# - Delete saved form data (destroy)
#
# Form-specific prefill logic is handled by FormProfile subclasses.
#
# Related files for MDOT form (Medical Device Ordering Tool):
# - Form profile class: app/models/form_profiles/mdot.rb
# - Form persistence: app/models/in_progress_form.rb
# - Form registration: app/models/form_profile.rb
# - Form profile mapping: config/form_profile_mappings/MDOT.yml
# - MDOT client library: lib/mdot/

module V0
  class InProgressFormsController < ApplicationController
    include IgnoreNotFound
    service_tag 'save-in-progress'

    def index
      # the keys of metadata shouldn't be deeply transformed, which might corrupt some keys
      # see https://github.com/department-of-veterans-affairs/va.gov-team/issues/17595 for more details
      pending_submissions = InProgressForm.submission_pending.for_user(@current_user)
      render json: InProgressFormSerializer.new(pending_submissions)
    end

    def show
      render json: form_for_user&.data_and_metadata || camelized_prefill_for_user
    end

    def update
      if Flipper.enabled?(:in_progress_form_atomicity, @current_user)
        atomic_update
      else
        original_update
      end
    end

    def destroy
      raise Common::Exceptions::RecordNotFound, form_id if form_for_user.blank?

      form_for_user.destroy
      render json: InProgressFormSerializer.new(form_for_user)
    end

    private

    def original_update
      form = InProgressForm.form_for_user(form_id, @current_user) ||
             InProgressForm.new(form_id:, user_uuid: @current_user.uuid)
      form.user_account = @current_user.user_account
      form.real_user_uuid = @current_user.uuid

      ClaimFastTracking::MaxCfiMetrics.log_form_update(form, params)

      form.update!(
        form_data: params[:form_data] || params[:formData],
        metadata: params[:metadata],
        expires_at: form.next_expires_at
      )

      render json: InProgressFormSerializer.new(form)
    end

    def atomic_update
      form_data = params[:form_data] || params[:formData]
      InProgressForm.transaction do
        # Lock the specific row to prevent concurrent updates, and use create_or_find_by! to prevent concurrent creation
        form = InProgressForm.form_for_user(form_id, @current_user, with_lock: true) ||
               InProgressForm.create_or_find_by!(form_id:, user_uuid: @current_user.uuid) do |f|
                 f.form_data = form_data
                 f.metadata = params[:metadata]
                 f.user_account = @current_user.user_account
               end

        form.user_account = @current_user.user_account if @current_user.user_account
        form.real_user_uuid = @current_user.uuid

        ClaimFastTracking::MaxCfiMetrics.log_form_update(form, params)

        form.update!(form_data:, metadata: params[:metadata], expires_at: form.next_expires_at)

        render json: InProgressFormSerializer.new(form)
      end
    end

    def form_for_user
      @form_for_user ||= InProgressForm.submission_pending.form_for_user(form_id, @current_user)
    end

    def form_id
      params[:id]
    end

    # the front end is always expecting camelCase
    # --this ensures that, even if the OliveBranch inflection header isn't used, camelCase keys are sent
    def camelized_prefill_for_user
      camelize_with_olivebranch(FormProfile.for(form_id: params[:id], user: @current_user).prefill.as_json)
    end

    def camelize_with_olivebranch(form_json)
      # camelize exactly as OliveBranch would
      # inspired by vets-api/blob/327b26c76ea7904744014ea35463022e8b50f3fb/lib/tasks/support/schema_camelizer.rb#L27
      OliveBranch::Transformations.transform(
        form_json,
        OliveBranch::Transformations.method(:camelize)
      )
    end
  end
end
