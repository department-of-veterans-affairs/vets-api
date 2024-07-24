module AccreditedRepresentativePortal
  module V0
    class RepresentativeUserInProgressFormsController
      def update
        form = InProgressForm.where(form_id:, user_uuid: @current_user.uuid).first_or_initialize
        form.update!(form_data: params[:form_data] || params[:formData], metadata: params[:metadata])

        render json: form, key_transform: :unaltered
      end

      private

      def form_id
        params[:id]
      end
    end
  end
end
