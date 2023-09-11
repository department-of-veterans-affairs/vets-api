# frozen_string_literal: true

class DynamicsService
  def get_user_inquiries(uuid:)
    inquiries_parsed_data.select do |inquiry|
      inquiry[:userUuid] == uuid
    end
  end

  def get_inquiry(inquiry_number:)
    inquiries_parsed_data.find { |data| data[:inquiryNumber] == inquiry_number } || {}
  end

  def get_reply(inquiry_number:)
    replies_parsed_data.find { |data| data[:inquiryNumber] == inquiry_number } || {}
  end

  def inquiries_parsed_data
    data = File.read('./modules/ask_va_api/config/locales/inquiries_mock_data.json')

    JSON.parse(data, symbolize_names: true)[:data]
  end

  def replies_parsed_data
    data = File.read('./modules/ask_va_api/config/locales/replies_mock_data.json')

    JSON.parse(data, symbolize_names: true)[:data]
  end
end
