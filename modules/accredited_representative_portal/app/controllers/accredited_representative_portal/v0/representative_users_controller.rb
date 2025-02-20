# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class RepresentativeUsersController < ApplicationController
      skip_after_action :verify_pundit_authorization

      def show
        log_info(
          'Retrieved in progress forms count',
          'api.arp.user.forms.count',
          ["count:#{in_progress_forms.length}"]
        )

        render json: {
          account: {
            accountUuid: @current_user.user_account_uuid
          },
          profile: {
            firstName: @current_user.first_name,
            lastName: @current_user.last_name,
            verified: @current_user.user_account.verified?,
            signIn: {
              serviceName: @current_user.sign_in[:service_name]
            }
          },
          prefillsAvailable: [],
          inProgressForms: in_progress_forms
        }
      end

      private

      def in_progress_forms
        InProgressForm.for_user(@current_user).map do |form|
          {
            form: form.form_id,
            metadata: form.metadata,
            lastUpdated: form.updated_at.to_i
          }
        end
      end
    end
  end
end
