# frozen_string_literal: true

RSpec.configure do |config|
  config.before :each, type: :request do
    Flipper.enable('va_online_scheduling')
  end

  config.define_derived_metadata(file_path: %r{modules/mobile/spec}) do |metadata|
    metadata[:json_api] = true
  end

  config.after :each, type: :request,json_api: true do |example|
    content_type = response.header['Content-Type']

    if content_type != 'application/pdf' && response.body.present? && example.metadata[:json_api] &&
       response.body != 'null' && !example.metadata[:skip_json_api_validation]

      expect(JSONAPI.parse_response!(response.parsed_body)).to eq(nil)
    end
  end
end
