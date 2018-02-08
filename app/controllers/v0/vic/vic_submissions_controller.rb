# frozen_string_literal: true

module V0
  module VIC
    class VICSubmissionsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        vic_submission = ::VIC::VICSubmission.new(
          params.require(:vic_submission).permit(:form)
        )
        vic_submission.user_uuid = current_user.uuid if current_user.present?

        unless vic_submission.save
          validation_error = vic_submission.errors.full_messages.join(', ')

          log_message_to_sentry(validation_error, :error, {}, validation: 'vic')

          raise Common::Exceptions::ValidationErrors, vic_submission
        end

        render(json: vic_submission)
      end

      def show
        render(json: ::VIC::VICSubmission.find_by(guid: params[:id]))
      end
    end
  end
end
