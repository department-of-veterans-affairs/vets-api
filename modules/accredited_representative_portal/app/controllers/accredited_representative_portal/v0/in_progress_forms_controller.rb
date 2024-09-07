# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class InProgressFormsController < ApplicationController
      def update
        form = InProgressForm.where(form_id:, user_uuid: @current_user.uuid).first_or_initialize
        form.update!(form_data: params[:formData], metadata: params[:metadata])

        render json: form, key_transform: :unaltered
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

      def in_progress_form
        return @in_progress_form if defined?(@in_progress_form)

        @in_progress_form = form_for_user(form_id)
      end

      def form_id
        params[:id]
      end
    end
  end
end
