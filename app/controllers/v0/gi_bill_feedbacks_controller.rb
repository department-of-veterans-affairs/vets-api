# frozen_string_literal: true

module V0
  class GIBillFeedbacksController < ApplicationController
    service_tag 'gibill-feedback'
    skip_before_action(:authenticate)
    before_action :load_user, only: :create

    def show
      gi_bill_feedback = GIBillFeedback.find(params[:id])
      render json: GIBillFeedbackSerializer.new(gi_bill_feedback)
    end

    def create
      gi_bill_feedback = GIBillFeedback.new(
        params.require(:gi_bill_feedback).permit(:form).merge(
          user: current_user
        )
      )

      unless gi_bill_feedback.save
        Sentry.set_tags(validation: 'gibft')

        raise Common::Exceptions::ValidationErrors, gi_bill_feedback
      end

      clear_saved_form(GIBillFeedback::FORM_ID)

      render json: GIBillFeedbackSerializer.new(gi_bill_feedback)
    end
  end
end
