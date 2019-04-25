# frozen_string_literal: true

module V0
  module Notifications
    class DismissedStatusesController < ApplicationController
      include Accountable
      include ::Notifications::Validateable

      before_action -> { validate_subject!(subject) }
      before_action -> { validate_status!(status) }, only: :create
      before_action :set_account, :set_notification

      def show
        if @notification
          render json: @notification, serializer: DismissedStatusSerializer
        else
          raise Common::Exceptions::RecordNotFound.new(subject), 'No matching record found for that user'
        end
      end

      private

      def set_account
        @account = create_user_account
      end

      def set_notification
        @notification = Notification.find_by(account_id: @account.id, subject: subject)
      end

      def dismissed_statuses_params
        params.permit(:subject, :dismissed_status, :status_effective_at)
      end

      def subject
        dismissed_statuses_params[:subject]
      end
    end
  end
end
