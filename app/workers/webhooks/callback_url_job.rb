# frozen_string_literal: true

module Webhooks
  class CallbackUrlJob
    include Sidekiq::Worker

    MAX_BODY_LENGTH = 500 # denotes the how large of a body from the client url we record in our db.

    def perform(url, ids, max_retries)
      @url = url
      @ids = ids
      @max_retries = max_retries
      r = Webhooks::Notification.where(id: ids)
      @msg = { 'notifications' => [] }
      r.each do |notification|
        @msg['notifications'] << notification.msg
      end
      Rails.logger.info "Webhooks::CallbackUrlJob Notifying on callback url #{url} for ids #{ids} with msg #{@msg}"
      notify
    end

    private

    def notify
      @response = Faraday.post(@url, @msg.to_json, 'Content-Type' => 'application/json')
    rescue Faraday::ClientError, Faraday::Error => e
      Rails.logger.error("Webhooks::CallbackUrlJob Error in CallbackUrlJob #{e.message}", e)
      @response = e
    rescue => e
      Rails.logger.error("Webhooks::CallbackUrlJob unexpected Error in CallbackUrlJob #{e.message}", e)
      @response = e
    ensure
      record_attempt
    end

    def record_attempt
      ActiveRecord::Base.transaction do
        successful = false
        if @response.respond_to? :success?
          successful = @response.success?
          attempt_response = { 'status' => @response.status, 'body' => @response.body[0...MAX_BODY_LENGTH] }
        else
          attempt_response = { 'exception' => @response.message }
        end

        # create the notification attempt record
        attempt = create_attempt(successful, attempt_response)

        # write an association record tied to each notification used in this attempt
        Webhooks::Notification.where(id: @ids).each do |notification|
          create_attempt_assoc(notification, attempt)

          # seal off the attempt if we received a successful response or hit our max retry limit
          if attempt.success? || notification.webhooks_notification_attempts.count >= @max_retries
            notification.final_attempt_id = attempt.id
          end

          notification.processing = nil
          notification.save!
        end
      end
    end

    def create_attempt(successful, response)
      attempt = Webhooks::NotificationAttempt.new do |a|
        a.success = successful
        a.response = response
      end
      attempt.save!
      attempt
    end

    def create_attempt_assoc(notification, attempt)
      attempt_assoc = Webhooks::NotificationAttemptAssoc.new do |naa|
        naa.webhooks_notification_id = notification.id
        naa.webhooks_notification_attempt_id = attempt.id
      end
      attempt_assoc.save!
      attempt_assoc
    end
  end
end
