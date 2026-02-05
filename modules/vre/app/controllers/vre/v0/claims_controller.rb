# frozen_string_literal: true

module VRE
  module V0
    class ClaimsController < ::ClaimsBaseController
      service_tag 'vre-application'
      before_action :authenticate
      skip_before_action :load_user

      def create
        if claim.save
          VRE::VRESubmit1900Job.perform_async(claim.id, encrypted_user)
          Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
          clear_saved_form(claim.form_id)
          render json: ::SavedClaimSerializer.new(claim)
        else
          StatsD.increment("#{stats_key}.failure")
          Sentry.set_tags(team: 'vfs-ebenefits') # tag sentry logs with team name
          Rails.logger.error('VR&E claim was not saved', { error_messages: claim.errors,
                                                           user_logged_in: current_user.present?,
                                                           current_user_uuid: current_user&.uuid })
          raise ::Common::Exceptions::ValidationErrors, claim
        end
      end

      private

      def user_account
        @user_account ||= UserAccount.find_by(icn: current_user.icn) if current_user.icn.present?
      end

      def claim
        @claim ||= SavedClaim::VeteranReadinessEmploymentClaim.new(form: filtered_params[:form], user_account:)
      end

      def filtered_params
        params.require(:veteran_readiness_employment_claim).permit(:form)
      end

      def short_name
        'veteran_readiness_employment_claim'
      end

      def encrypted_user
        user_struct = OpenStruct.new(
          participant_id: current_user.participant_id,
          pid: current_user.participant_id,
          edipi: current_user.edipi,
          vet360_id: current_user.vet360_id,
          birth_date: current_user.birth_date,
          ssn: current_user.ssn,
          loa3?: current_user.loa3?,
          uuid: current_user.uuid,
          icn: current_user.icn,
          first_name: current_user.first_name,
          va_profile_email: current_user.va_profile_email
        )
        KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json)
      end
    end
  end
end
