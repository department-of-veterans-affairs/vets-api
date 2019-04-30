# frozen_string_literal: true

module V0
  class NotificationsController < ApplicationController
    include Accountable
    include ::Notifications::Validateable

    before_action -> { validate_subject!(subject) }
    before_action :set_account
    before_action :set_notification, only: :show

    def create
      notification = @account.notifications.build(subject: subject, read_at: read_at)

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

    private

    def set_account
      @account = create_user_account
    end

    def set_notification
      @notification = Notification.find_by(account_id: @account.id, subject: subject)
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
