# frozen_string_literal: true

class DynamicsMockService
  class FileNotFound < StandardError; end
  class InvalidJSONContent < StandardError; end

  def initialize(icn: nil, logger: nil)
    @icn = icn
    @logger = logger
  end

  def call(endpoint:, method: :get, payload: {})
    raise ArgumentError, 'Only :get method is supported' unless method == :get

    @payload = payload
    file_path = file_path_for(endpoint)
    data = read_and_parse_json(file_path)
    filter_mock_data(data)
  rescue Errno::ENOENT
    raise FileNotFound, "Mock file not found for #{endpoint}"
  rescue JSON::ParserError
    raise InvalidJSONContent, "Invalid JSON content for #{endpoint}"
  end

  private

  def file_path_for(endpoint)
    "modules/ask_va_api/config/locales/#{sanitize_endpoint(endpoint)}"
  end

  def read_and_parse_json(file_path)
    JSON.parse(File.read(file_path), symbolize_names: true)[:data]
  end

  def sanitize_endpoint(endpoint)
    "#{endpoint.tr('/', '_')}.json"
  end

  def filter_mock_data(data)
    return data if @payload.blank?

    key, value = @payload.first
    key = camelize_key(key)
    data.select { |item| item[key.to_sym].to_i == formatted_value(key, value).to_i }
  end

  def camelize_key(key)
    parts = key.to_s.split('_')
    parts[0] + parts[1..].collect(&:capitalize).join
  end

  def formatted_value(key, value)
    key.to_s.end_with?('Id') ? value.to_i : value
  end
end
