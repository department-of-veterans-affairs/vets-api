# frozen_string_literal: true

require 'income_and_assets/monitor'

module V0
  class IncomeAndAssetsClaimsController < ClaimsBaseController
    before_action :check_flipper_flag
    service_tag 'income-and-assets-application'

    def short_name
      'income_and_assets_claim'
    end

    def claim_class
      SavedClaim::IncomeAndAssets
    end

    def show
      claim = claim_class.find_by!(guid: params[:id]) # raises ActiveRecord::RecordNotFound
      render json: SavedClaimSerializer.new(claim)
    rescue ActiveRecord::RecordNotFound => e
      ia_monitor.track_show404(params[:id], current_user.user_account_uuid, e)
      render(json: { error: e.to_s }, status: :not_found)
    rescue => e
      ia_monitor.track_show_error(params[:id], current_user.user_account_uuid, e)
      raise e
    end

    def create
      claim = claim_class.new(form: filtered_params[:form])
      ia_monitor.track_create_attempt(claim, current_user.user_account_uuid)

      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.form_start_date = in_progress_form.created_at if in_progress_form

      unless claim.save
        ia_monitor.track_create_error(in_progress_form, claim, current_user.user_account_uuid)
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim.errors
      end

      claim.upload_to_lighthouse(current_user)

      ia_monitor.track_create_success(in_progress_form, claim, current_user.user_account_uuid)

      clear_saved_form(claim.form_id)
      render json: SavedClaimSerializer.new(claim)
    rescue => e
      ia_monitor.track_create_error(in_progress_form, claim, current_user.user_account_uuid, e)
      raise e
    end

    private

    # Raises an exception if the income and assets flipper flag isn't enabled.
    def check_flipper_flag
      raise Common::Exceptions::Forbidden unless Flipper.enabled?(:pension_income_and_assets_clarification,
                                                                  current_user)
    end

    def log_validation_error_to_metadata(in_progress_form, claim)
      return if in_progress_form.blank?

      metadata = in_progress_form.metadata
      metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
      in_progress_form.update(metadata:)
    end

    def format_show_response(claim, state, form_submission, submission_attempt)
      {
        data: {
          id: claim.id,
          form_id: claim.form_id,
          guid: claim.guid,
          attributes: {
            state:,
            benefits_intake_uuid: form_submission.benefits_intake_uuid,
            form_type: form_submission.form_type,
            attempt_id: submission_attempt.id,
            aasm_state: submission_attempt.aasm_state
          }
        }
      }
    end

    def ia_monitor
      @monitor ||= IncomeAndAssets::Monitor.new
    end
  end
end
