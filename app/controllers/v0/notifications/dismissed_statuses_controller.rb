# frozen_string_literal: true

module V0
  module Notifications
    # This class is for any notification `status` and `status_effective_at` related updates and use cases,
    # for a given subject.
    #
    # For any conventional read/unread notification use cases, use the notifications_controller.rb
    #
    class DismissedStatusesController < ApplicationController
      include ::Notifications::Validateable

      before_action -> { validate_subject!(subject) }
      before_action -> { validate_status!(status) }, only: %i[create update]
      before_action :set_notification
      before_action -> { validate_record_present!(@notification, subject) }, only: :update

      def create
        notification = @current_user.account.notifications.build(dismissed_statuses_params.merge(read_at: Time.current))

        if notification.save
          render json: notification, serializer: DismissedStatusSerializer
        else
          raise Common::Exceptions::ValidationErrors.new(notification), 'Validation errors present'
        end
      end

      def show
        if @notification
          render json: @notification, serializer: DismissedStatusSerializer
        else
          raise Common::Exceptions::RecordNotFound.new(subject), 'No matching record found for that user'
        end
      end

      def update
        if @notification.update(dismissed_statuses_params.merge(read_at: Time.current))
          render json: @notification, serializer: DismissedStatusSerializer
        else
          raise Common::Exceptions::ValidationErrors.new(@notification), 'Validation errors present'
        end
      end

      private

      def set_notification
        @notification = Notification.find_by(account_id: @current_user.account_id, subject: subject)
      end

      def dismissed_statuses_params
        params.permit(:subject, :status, :status_effective_at)
      end

      def subject
        dismissed_statuses_params[:subject]
      end

      def status
        dismissed_statuses_params[:status]
      end
    end
  end
end
