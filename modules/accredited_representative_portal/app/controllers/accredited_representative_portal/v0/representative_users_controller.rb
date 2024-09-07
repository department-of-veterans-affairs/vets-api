# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class RepresentativeUsersController < ApplicationController
      def show
        # TODO: Move to serializer. Temporary quick and dirty.
        render json: {
          account: {
            # Correct value?
            account_uuid: @current_user.uuid,
          },
          profile: {
            first_name: @current_user.first_name,
            last_name: @current_user.last_name,
            verified:,
          },
          # TODO: Should they get prefill for e.g. 21a?
          prefills_available: [],
          in_progress_forms:,
        }
      end

      private

      def in_progress_forms
        InProgressForm.submission_pending.for_user(@current_user).map do |form|
          {
            form: form.form_id,
            metadata: form.metadata,
            lastUpdated: form.updated_at.to_i
          }
        end
      end

      # Move to model? Logic taken from elsewhere.
      def verified
        loa = @current_user.loa.to_h[:current]&.to_i
        loa == SignIn::Constants::Auth::LOA_THREE
      end
    end
  end
end
