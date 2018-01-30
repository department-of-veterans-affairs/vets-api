# frozen_string_literal: true

module V0
  module VIC
    class VICSubmissionsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        vic_submission = ::VIC::VICSubmission.new(
          params.require(:vic_submission).permit(:form)
        )

        unless vic_submission.save
          validation_error = vic_submission.errors.full_messages.join(', ')

          log_message_to_sentry(validation_error, :error, {}, validation: 'vic')

          raise Common::Exceptions::ValidationErrors, vic_submission
        end

        render(json: vic_submission)
      end

      def show
        # TODO spec for this ctrl
      end
    end
  end
end
