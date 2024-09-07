# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class RepresentativeUsersController < ApplicationController
      def show
        # TODO: Once we figure out how we're handling serialization and which library we're using,
        # moving this serialization logic out to to a serialization layer.
        render json: {
          account: {
            # NOTE: In regard to the in progress form system, this value is only
            # showing up as error log metadata that identifies a user. To note
            # is that the VA.gov-wide implementation is exposing the CSP user
            # ID, while we are improving upon that by exposing the ARP user ID
            # which will make investigating errors easier. However, it might
            # confuse someone who is used to debugging the VA.gov-wide scenario.
            account_uuid: @current_user.user_account_uuid
          },
          profile: {
            first_name: @current_user.first_name,
            last_name: @current_user.last_name,
            verified: @current_user.verified?,
            sign_in: {
              service_name: @current_user.sign_in[:service_name]
            }
          },
          prefills_available: [],
          in_progress_forms:
        }
      end

      private

      def in_progress_forms
        in_progress_forms_for_user.map do |form|
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
