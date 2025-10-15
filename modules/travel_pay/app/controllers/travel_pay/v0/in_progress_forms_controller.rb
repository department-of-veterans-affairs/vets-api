# frozen_string_literal: true

module TravelPay
  module V0
    class InProgressFormsController < ::V0::InProgressFormsController
      private

      # Override the parent form_id method to include claim_id
      def form_id
        form_data = params[:form_data]
        if form_data.present?
          "#{params[:id]}_#{form_data['claim_id']}"
        else
          params[:id]
        end
      end
    end
  end
end
