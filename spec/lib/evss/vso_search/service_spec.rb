# frozen_string_literal: true

require 'rails_helper'
require 'evss/vso_search/service'

describe EVSS::VSOSearch::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user, nil) }
  let(:response) { OpenStruct.new(body: get_fixture('json/evss_with_poa')) }

  def it_returns_valid_payload(method, form = nil)
    allow(service).to receive(:perform).and_return(response)
    service.send(*[method, form].compact)
  end

  def it_handles_errors(method, form = nil, form_id = nil)
    allow(service).to receive(:perform).and_raise(Faraday::ParsingError)
    expect(service).to receive(:handle_error)
    service.send(*[method, form, form_id].compact)
  end

  describe '#get_current_info' do
    it 'with a valid evss response' do
      it_returns_valid_payload(:get_current_info, response.body)
    end

    it 'handles errors' do
      it_handles_errors(:get_current_info, response.body)
    end

    it 'uses passed in user account data if auth_headers are missing' do
      headers = {
        'Authorization' => 'Token token=PUBLICDEMO123',
        'Content-Type' => 'application/json',
        'edipi' => '1007697216',
        'ssn' => '796043735'
      }
      expect(service).to receive(:perform).with(:post, 'getCurrentInfo', '', headers).and_return(response)
      service.send(*[:get_current_info, {}].compact)
    end

    it 'sets the correct base headers and empty string for post body' do
      headers = JSON.parse(File.read('spec/fixtures/evss_vso_search/service_headers.json'))
      expect(service).to receive(:perform).with(:post, 'getCurrentInfo', '', headers).and_return(response)
      service.send(*[:get_current_info, response.body].compact)
    end

    it 'overrides the request ssn' do
      headers =
        {
          'va_eauth_pnid' => '222334567'
        }

      merged_headers = {
        'ssn' => '222334567',
        'edipi' => '1007697216',
        'Authorization' => 'Token token=PUBLICDEMO123',
        'Content-Type' => 'application/json',
        'va_eauth_pnid' => '222334567'
      }

      expect(service).to receive(:perform).with(:post, 'getCurrentInfo', '', merged_headers).and_return(response)
      service.send(*[:get_current_info, headers].compact)
    end

    it 'overrides the request edipi' do
      headers =
        {
          'va_eauth_dodedipnid' => '2007697216'
        }

      merged_headers = {
        'ssn' => '796043735',
        'edipi' => '2007697216',
        'Authorization' => 'Token token=PUBLICDEMO123',
        'Content-Type' => 'application/json',
        'va_eauth_dodedipnid' => '2007697216'
      }

      expect(service).to receive(:perform).with(:post, 'getCurrentInfo', '', merged_headers).and_return(response)
      service.send(*[:get_current_info, headers].compact)
    end

    it 'does not override user fields without additional_headers' do
      merged_headers = {
        'ssn' => '796043735',
        'edipi' => '1007697216',
        'Authorization' => 'Token token=PUBLICDEMO123',
        'Content-Type' => 'application/json'
      }

      expect(service).to receive(:perform).with(:post, 'getCurrentInfo', '', merged_headers).and_return(response)
      service.send(*[:get_current_info].compact)
    end
  end
end
