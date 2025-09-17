# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class RepresentativeUsersController < ApplicationController
      skip_after_action :verify_pundit_authorization

      def show
        # TODO: Once we figure out how we're handling serialization and which
        # library we're using, moving this serialization logic out to to a
        # serialization layer.
        ar_monitoring.trace('ar.users.show',
                            tags: { 'users_show.poa_codes' => poa_codes }) do |_span|
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
              },
              loa: @current_user.loa
            },
            prefillsAvailable: [],
            inProgressForms: in_progress_forms
          }
        end
      end

      def authorize_as_representative
        authorize %i[accredited_representative_portal authorization], :authorize_as_representative?
        head :no_content
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

      def ar_monitoring
        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: [
            "controller:#{controller_name}",
            "action:#{action_name}"
          ].compact
        )
      end

      def poa_codes
        current_user.power_of_attorney_holders.map(&:poa_code)
      end
    end
  end
end
