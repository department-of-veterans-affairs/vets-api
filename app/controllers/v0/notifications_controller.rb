# frozen_string_literal: true

module V0
  # This class is for any conventional read/unread notification use cases, for a given subject.
  #
  # For any `status` and `status_effective_at` related updates and use cases, use the
  # notifications/dismissed_statuses_controller.rb
  #
  class NotificationsController < ApplicationController
    include ::Notifications::Validateable

    before_action -> { validate_subject!(subject) }
    before_action :set_notification, only: %i[show update]

    def create
      notification = @current_user.account.notifications.build(subject: subject, read_at: read_at)

      if notification.save
        render json: notification, serializer: NotificationSerializer
      else
        raise Common::Exceptions::ValidationErrors.new(notification), 'Validation errors present'
      end
    end

    def show
      if @notification
        render json: @notification, serializer: NotificationSerializer
      else
        raise Common::Exceptions::RecordNotFound.new(subject), 'No matching record found for that user'
      end
    end

    def update
      validate_record_present!(@notification, subject)

      if @notification.update(read_at: read_at)
        render json: @notification, serializer: NotificationSerializer
      else
        raise Common::Exceptions::ValidationErrors.new(@notification), 'Validation errors present'
      end
    end

    private

    def set_notification
      @notification = Notification.find_by(account_id: @current_user.account_id, subject: subject)
    end

    def notification_params
      params.permit(:subject, :read)
    end

    def subject
      notification_params[:subject]
    end

    def read_at
      notification_params[:read] == true ? Time.current : nil
    end
  end
end
