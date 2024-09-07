# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class InProgressFormsController < ApplicationController
      def update
        form = InProgressForm.where(form_id:, user_uuid: @current_user.uuid).first_or_initialize
        form.update!(form_data: params[:form_data] || params[:formData], metadata: params[:metadata])

        render json: form, key_transform: :unaltered
      end

      def show
        render json: form_for_user&.data_and_metadata
      end

      def destroy
        raise Common::Exceptions::RecordNotFound, form_id if form_for_user.blank?

        form_for_user.destroy
        render json: form_for_user, key_transform: :unaltered
      end

      private

      def form_for_user
        @form_for_user ||= InProgressForm.submission_pending.form_for_user(form_id, @current_user)
      end

      def form_id
        params[:id]
      end
    end
  end
end
