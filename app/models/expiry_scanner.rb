# frozen_string_literal: true

require 'common/client/base'
require 'find'
require 'openssl'
require 'date'

# Adding comment to trigger manifest deployment

class ExpiryScanner
  REMAINING_DAYS = 60
  URGENT_REMAINING_DAYS = 30
  API_PATH = 'https://slack.com/api/chat.postMessage'

  def self.scan_certs
    result = false
    messages = ["Vets-Api #{Settings.vsp_environment} - SSL certificate scan result"]
    cert_paths = Dir.glob(directories)
    cert_paths.each do |cert_path|
      if ['.pem', '.crt'].include?(File.extname(cert_path))
        message = define_expiry_urgency(cert_path)
        if message.present?
          messages << message
          result = true
        end
      end
    rescue
      Rails.logger.debug { "ERROR: Could not parse certificate #{cert_path}" }
    end
    Faraday.post(API_PATH, request_body(messages.join("\n")), request_headers) if result
  end

  def self.define_expiry_urgency(cert_path)
    now = DateTime.now
    cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
    expiry = cert.not_after.to_datetime
    return nil if expiry > now + REMAINING_DAYS

    if now + URGENT_REMAINING_DAYS > expiry
      "URGENT: #{cert_path} expires in less than #{URGENT_REMAINING_DAYS} days: #{expiry}"
    else
      "ATTENTION: #{cert_path} expires in less than #{REMAINING_DAYS} days: #{expiry}"
    end
  end

  def self.request_body(message)
    {
      text: message,
      channel: Settings.expiry_scanner.slack.channel_id
    }.to_json
  end

  def self.request_headers
    {
      'Content-type' => 'application/json; charset=utf-8',
      'Authorization' => "Bearer #{Settings.argocd.slack.api_key}"
    }
  end

  def self.directories
    Settings.expiry_scanner.directories
  end
end
