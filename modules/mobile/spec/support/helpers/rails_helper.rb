# frozen_string_literal: true

require 'rails_helper'
require_relative 'spec_helper'
require_relative 'sis_session_helper'
require_relative '../../support/matchers/json_schema_matcher'

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{modules/mobile/spec}) do |metadata|
    metadata[:mobile_spec] = true
  end

  # Many specs have been known to inconsistently fail without this flipper enabled.
  # Not every spec needs it but no specs need it disabled so to ensure we don't get flaky specs
  # this will just be enabled for all specs
  config.before :each, :mobile_spec, type: :request do
    Flipper.enable('va_online_scheduling')
  end

  config.after :each, :mobile_spec, type: :request do |example|
    content_type = response.header['Content-Type']

    if content_type != 'application/pdf' && response.body.present? &&
       response.body != 'null' && !example.metadata[:skip_json_api_validation]

      expect(JSONAPI.parse_response!(response.parsed_body)).to eq(nil)
    end
  end

  config.before :each, :openapi_schema_validation, type: :request do
    config.include Committee::Rails::Test::Methods
    config.add_setting :committee_options
    config.committee_options = {
      schema_path: Rails.root.join('modules', 'mobile', 'docs', 'openapi.json').to_s,
      prefix: '/mobile',
      strict_reference_validation: true
    }
  end

  config.after :each, :openapi_schema_validation, type: :request do
    config.committee_options = nil
  end
end
