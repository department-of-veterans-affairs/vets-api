# frozen_string_literal: true

require 'rails_helper'
require 'statsd_endpoint_tag_filter'

RSpec.describe StatsdEndpointTagFilter do
  describe ".redact" do

    it 'does not redact versions' do
      endpoint = "/demographics/demographics/v1"
      expected_result = "/demographics/demographics/v1"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it "redacts 1.12.123.1.123456.1.123" do
      endpoint = "/demographics/demographics/v1/1.12.123.1.123456.1.123"
      expected_result = "/demographics/demographics/v1/xxx"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it "redacts hexidecimal path segments" do
      endpoint = "/api/vetext/pub/mobile/push/preferences/client/12ab123414f9191d4817409427447978862"
      expected_result = "/api/vetext/pub/mobile/push/preferences/client/xxx"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it "redacts encodings " do
      endpoint = "/communication-hub/communication/v1/12345678_5epi_5e200vets_5eusdva/communication-permissions"
      expected_result = "/communication-hub/communication/v1/xxx/communication-permissions"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it 'it keeps end paths' do
      endpoint = "/communication-hub/communication/v1/123456789abcdef/communication-permissions"
      expected_result = "/communication-hub/communication/v1/xxx/communication-permissions"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it "redacts UUIDs" do
      endpoint = "/demographics/demographics/v1/d12a1234-12a0-4f65-bc1d-4ab1cd89551d_5epn_5e200vlgn_5eusdva"
      expected_result = "/communication-hub/communication/v1/xxx/communication-permissions"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it 'combines redacted xxx' do
      endpoint = '/profile-service/profile/v3/1.12.123.1.123456.1.123/12345678_5epi_5e200vets_5eusdva'
      expected_result = "/profile-service/profile/v3/xxx"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end

    it "redacts multiple match" do
      endpoint = "/profile-service/profile/v3/1.12.123.1.123456.1.123/123456789_5eni_5e200dod_5eusdod"
      expected_result = "/profile-service/profile/v3/xxx"
      expect(StatsdEndpointTagFilter.redact(endpoint)).to eq(expected_result)
    end
  end
end
