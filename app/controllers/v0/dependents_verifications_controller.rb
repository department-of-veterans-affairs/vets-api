# frozen_string_literal: true

module V0
  class DependentsVerificationsController < ApplicationController
    service_tag 'dependency-verification'

    def index
      dependents = dependency_verification_service.read_diaries

      render json: DependentsVerificationsSerializer.new(dependents)
    end

    def create
      return if filtered_params[:form][:update_diaries] == 'false'

      claim = SavedClaim::DependencyVerificationClaim.new(form: filtered_params[:form].to_json)
      claim.add_claimant_info(current_user) if current_user&.loa3?

      unless claim.save
        StatsD.increment('api.dependency_verification_claim.failure')
        Sentry.set_tags(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.send_to_central_mail! if current_user&.loa3?

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)

      render json: SavedClaimSerializer.new(claim)
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
