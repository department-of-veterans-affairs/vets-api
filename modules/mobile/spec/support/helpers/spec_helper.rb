# frozen_string_literal: true

RSpec.configure do |config|
  config.before :each, type: :request do
    Flipper.enable('va_online_scheduling')
  end

  config.after :each, type: :request do |example|
    content_type = response.header['Content-Type']

    if content_type != 'application/pdf' && response.body.present? &&
       response.body != 'null' && !example.metadata[:skip_json_api_validation]

      expect(JSONAPI.parse_response!(response.parsed_body)).to eq(nil)
    end
  end
end
