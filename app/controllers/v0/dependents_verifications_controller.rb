# frozen_string_literal: true

module V0
  class DependentsVerificationsController < ClaimsBaseController
    def index
      load_user
      dependents = dependency_verification_service.read_diaries
      render json: dependents, serializer: DependentsVerificationsSerializer
    end

    def create
      return if filtered_params[:update_diaries] == 'false'

      load_user
      claim = SavedClaim::DependencyVerificationClaim.new(form: filtered_params[:form].to_json)
      claim.add_claimant_info(current_user) if current_user&.loa3?

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.send_to_central_mail!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)

      render(json: claim)
    end

    private

    def dependency_verification_service
      @dependent_service ||= BGS::DependencyVerificationService.new(current_user)
    end

    def filtered_params
      params.require(:dependency_verification_claim)
    end
  end
end
