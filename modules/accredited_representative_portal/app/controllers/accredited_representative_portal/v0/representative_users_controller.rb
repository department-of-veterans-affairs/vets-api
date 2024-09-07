# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class RepresentativeUsersController < ApplicationController
      def show
        # TODO: Once we figure out how we're handling serialization and which library we're using,
        # moving this serialization logic out to to a serialization layer.
        render json: {
          account: {
            account_uuid: @current_user.uuid
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
