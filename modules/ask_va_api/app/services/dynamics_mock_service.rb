# frozen_string_literal: true

class DynamicsMockService
  class FileNotFound < StandardError; end
  class InvalidJSONContent < StandardError; end

  def initialize(sec_id: nil, logger: nil)
    @sec_id = sec_id
    @logger = logger
  end

  def call(endpoint:, method: :get, payload: {})
    @payload = payload
    if method == :get
      file_path = "modules/ask_va_api/config/locales/#{sanitize_endpoint(endpoint)}"
      data = JSON.parse(File.read(file_path), symbolize_names: true)[:data]
      filter_mock_data(data)
    end
  rescue Errno::ENOENT
    raise FileNotFound, "Mock file not found for #{endpoint}"
  rescue JSON::ParserError
    raise InvalidJSONContent, "Invalid JSON content for #{endpoint}"
  end

  private

  def sanitize_endpoint(endpoint)
    "#{endpoint.tr('/', '_')}.json"
  end

  def filter_mock_data(data)
    if @payload[:inquiry_number]
      data.find { |i| i[:inquiryNumber] == @payload[:inquiry_number] } || {}
    elsif @payload[:sec_id]
      data.select { |i| i[:sec_id] == @payload[:sec_id] }.map { |i| i.except(:attachments) }
    elsif @payload.blank?
      data
    else
      key = @payload.keys.first
      symbolize_key = key.to_s.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }.to_sym
      data.select { |i| i[symbolize_key] == @payload[key].to_i }
    end
  end
end
