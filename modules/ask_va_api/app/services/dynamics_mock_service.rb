# frozen_string_literal: true

class DynamicsMockService
  class FileNotFound < StandardError; end
  class InvalidJSONContent < StandardError; end

  def initialize(endpoint, method, criteria)
    @endpoint = endpoint
    @method = method
    @criteria = criteria
  end

  def call
    file_path = "modules/ask_va_api/config/locales/#{mock_filename}"
    data = JSON.parse(File.read(file_path), symbolize_names: true)[:data]
    filter_mock_data(data)
  rescue Errno::ENOENT
    raise FileNotFound, "Mock file not found for #{@endpoint}"
  rescue JSON::ParserError
    raise InvalidJSONContent, "Invalid JSON content for #{@endpoint}"
  end

  private

  def mock_filename
    "#{@endpoint.tr('/', '_')}.json"
  end

  def filter_mock_data(data)
    if @criteria[:inquiry_number]
      data.find { |i| i[:inquiryNumber] == @criteria[:inquiry_number] } || {}
    elsif @criteria[:sec_id]
      data.select { |i| i[:sec_id] == @criteria[:sec_id] }.map { |i| i.except(:attachments) }
    else
      data
    end
  end
end
