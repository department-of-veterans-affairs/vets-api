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
    "modules/ask_va_api/config/locales/get_#{endpoint}_mock_data.json"
  end

  def read_and_parse_json(file_path)
    JSON.parse(File.read(file_path), symbolize_names: true)[:Data]
  end

  def filter_mock_data(data)
    return data if @payload.blank?

    key, value = @payload.first
    key = sanitize_key(key)
    if key == 'Id'
      { Data: data.find { |item| item[key.to_sym].to_i == value.to_i } }
    else
      { Data: data.select { |item| item[key.to_sym].to_i == value.to_i } }
    end
  end

  def sanitize_key(key)
    key.to_s.gsub(/(\A.|_.)/) { ::Regexp.last_match(1).upcase }.gsub(/_/, '')
  end
end
