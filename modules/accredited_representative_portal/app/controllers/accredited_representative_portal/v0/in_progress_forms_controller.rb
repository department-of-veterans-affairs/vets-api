# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class InProgressFormsController < ApplicationController
      def update
        form = in_progress_form || new_form_for_user(form_id, @current_user)
        form.update!(form_data: params[:formData], metadata: params[:metadata])

        render json: InProgressFormSerializer.new(form)
      end

      def show
        render json: in_progress_form&.data_and_metadata || {}
      end

      def destroy
        raise Common::Exceptions::RecordNotFound, form_id if in_progress_form.blank?

        in_progress_form.destroy
        head :no_content
      end

      private

      # NOTE: The in-progress form module can upstream this convenience that
      # allows the caller to not know about the details of legacy foreign key
      # relations. It is totally analogous to the query convenience
      # `form_for_user` that they expose.
      def new_form_for_user(form_id, user)
        form =
          InProgressForm.new(
            form_id:,
            user_uuid: user.uuid,
            user_account: user.user_account
          )

        form.real_user_uuid = user.uuid
        form
      end

      def in_progress_form
        @in_progress_form ||=
          InProgressForm.form_for_user(form_id, @current_user)
      end

      def form_id
        params[:id]
      end
    end
  end
end
