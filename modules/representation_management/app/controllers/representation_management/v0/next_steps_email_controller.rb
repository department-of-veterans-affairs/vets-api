# frozen_string_literal: true

module RepresentationManagement
  module V0
    class NextStepsEmailController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate

      def create
        next_steps_email_data = RepresentationManagement::NextStepsEmailData.new(next_steps_email_params)
        p "next_steps_email_data: #{next_steps_email_data.inspect}",
          "next_steps_email_data.invalid?: #{next_steps_email_data.invalid?}"
        if next_steps_email_data.invalid?
          render json: { errors: next_steps_email_data.errors }, status: :unprocessable_entity and return
        else
          # send email and return ok
          render json: { message: 'Email sent' }, status: :ok
        end
      end

      private

      def next_steps_email_params
        params.require(:next_steps_email).permit(
          :first_name,
          :form_name,
          :form_number,
          :representative_type,
          :representative_name,
          :representative_address
        )
      end
    end
  end
end
