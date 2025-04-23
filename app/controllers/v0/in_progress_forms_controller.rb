# frozen_string_literal: true

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
      form = InProgressForm.form_for_user(form_id, @current_user) ||
             InProgressForm.new(form_id:, user_uuid: @current_user.uuid)
      form.user_account = @current_user.user_account
      form.real_user_uuid = @current_user.uuid

      if Flipper.enabled?(:disability_compensation_sync_modern0781_flow_ipf_metadata) &&
         (form_id == FormProfiles::VA526ez::FORM_ID)
        params[:metadata][:sync_modern0781_flow] = params[:form_data][:sync_modern0781_flow]
      end

      ClaimFastTracking::MaxCfiMetrics.log_form_update(form, params)

      form.update!(form_data: params[:form_data] || params[:formData], metadata: params[:metadata])
      itf_creation(form)

      render json: InProgressFormSerializer.new(form)
    end

    def destroy
      raise Common::Exceptions::RecordNotFound, form_id if form_for_user.blank?

      form_for_user.destroy
      render json: InProgressFormSerializer.new(form_for_user)
    end

    private

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

    def itf_creation(form)
      itf_valid_form = Lighthouse::CreateIntentToFileJob::ITF_FORMS.include?(form.form_id)
      itf_synchronous = Flipper.enabled?(:intent_to_file_synchronous_enabled, @current_user)

      if itf_valid_form && itf_synchronous
        itf_monitor.track_create_itf_initiated(form.form_id, form.created_at, @current_user.uuid, form.id)

        begin
          Lighthouse::CreateIntentToFileJob.new.perform(form.id, @current_user.icn, @current_user.participant_id)
        rescue Common::Exceptions::ResourceNotFound
          # prevent false error being reported to user - ICN present but not found by BenefitsClaims
          # todo: handle itf process from frontend
        end
      end
    end

    def itf_monitor
      @itf_monitor ||= BenefitsClaims::IntentToFile::Monitor.new
    end
  end
end
