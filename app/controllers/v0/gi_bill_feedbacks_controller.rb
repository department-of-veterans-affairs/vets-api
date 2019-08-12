# frozen_string_literal: true

module V0
  class GIBillFeedbacksController < ApplicationController
    skip_before_action(:authenticate)

    def create
      validate_session

      gi_bill_feedback = GIBillFeedback.new(
        params.require(:gi_bill_feedback).permit(:form).merge(
          user: current_user
        )
      )

      unless gi_bill_feedback.save
        Raven.tags_context(validation: 'gibft')

        raise Common::Exceptions::ValidationErrors, gi_bill_feedback
      end

      clear_saved_form(GIBillFeedback::FORM_ID)

      render(json: gi_bill_feedback)
    end

    def show
      render(json: GIBillFeedback.find(params[:id]))
    end
  end
end
