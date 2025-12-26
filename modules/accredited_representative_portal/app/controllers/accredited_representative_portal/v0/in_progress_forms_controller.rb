# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class InProgressFormsController < ApplicationController
      skip_after_action :verify_pundit_authorization
      before_action :feature_enabled

      def show
        form = find_form
        render json: form&.data_and_metadata || {}
      end

      def update
        form = find_form || build_form
        form.update!(
          form_data: params[:formData],
          metadata: params[:metadata],
          expires_at: form.next_expires_at
        )

        render json: InProgressFormSerializer.new(form)
      end

      def destroy
        form = find_form or
          raise Common::Exceptions::RecordNotFound, params[:id]
        form.destroy

        head :no_content
      end

      private

      # Checks if the feature flag accredited_representative_portal_form_21a is enabled or not
      def feature_enabled
        routing_error unless Flipper.enabled?(:accredited_representative_portal_form_21a)
      end

      def find_form
        InProgressForm.form_for_user(params[:id], @current_user)
      end

      def build_form
        build_form_for_user(params[:id], @current_user)
      end

      # NOTE: The in-progress form module can upstream this convenience that
      # allows the caller to not know about details like legacy foreign key
      # relations. It is totally analogous to the query convenience
      # `form_for_user` that they expose.
      def build_form_for_user(form_id, user)
        InProgressForm.new.tap do |form|
          form.real_user_uuid = user.uuid
          form.assign_attributes(
            user_uuid: user.uuid,
            user_account: user.user_account,
            form_id:
          )
        end
      end
    end
  end
end
