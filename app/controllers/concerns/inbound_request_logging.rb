# frozen_string_literal: true

require 'uri'

module InboundRequestLogging
  extend ActiveSupport::Concern

  private

  def log_inbound_request(message_type:, message:)
    referer_host = extract_referer_host(request.referer)

    Rails.logger.info(
      message,
      {
        message_type:,
        action: action_name,
        path: request.path,
        referer_host:,
        user_agent: request.user_agent,
        x_forwarded_host: request.headers['X-Forwarded-Host'],
        request_id: request.request_id
      }
    )
  end

  def extract_referer_host(referer)
    return nil if referer.blank?

    URI.parse(referer).host
  rescue URI::InvalidURIError
    nil
  end
end
