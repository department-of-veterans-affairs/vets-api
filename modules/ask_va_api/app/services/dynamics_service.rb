# frozen_string_literal: true

class DynamicsService
  class DynamicsServiceError < StandardError; end

  def get_user_inquiries(uuid:)
    parsed_data.select do |inquiry|
      inquiry[:userUuid] == uuid
    end
  end

  def get_inquiry(inquiry_number:)
    inquiry = parsed_data.find { |data| data[:inquiryNumber] == inquiry_number }

    raise DynamicsServiceError, "Record with Inquiry Number: #{inquiry_number} is invalid" if inquiry.nil?

    inquiry
  end

  def parsed_data
    data = File.read('./modules/ask_va_api/config/locales/mock_data.json')

    JSON.parse(data, symbolize_names: true)[:data]
  end
end
