# frozen_string_literal: true

module Notifications
  module Validateable
    extend ActiveSupport::Concern

    def validate_subject!(subject)
      unless Notification.subjects.keys.include?(subject)
        message = "#{subject} is not a valid subject"

        raise Common::Exceptions::UnprocessableEntity.new(detail: message), message
      end
    end

    def validate_status!(status)
      unless Notification.statuses.keys.include?(status)
        message = "#{status} is not a valid status"

        raise Common::Exceptions::UnprocessableEntity.new(detail: message), message
      end
    end

    def validate_record_present!(notification, subject)
      if notification.nil?
        raise Common::Exceptions::RecordNotFound.new(subject), "User does not have a #{subject} record"
      end
    end
  end
end
