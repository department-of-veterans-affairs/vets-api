# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::OgcClient do
  subject { described_class.new }

  let(:icn) { '1234567890V123456' }
  let(:api_url) { 'https://api.example.gov/v1/representatives/icn' }
  let(:api_key) { 'test-api-key' }
  let(:origin) { 'https://va.gov' }

  before do
    allow(Settings.gclaws.accreditation.icn).to receive(:url).and_return(api_url)
    allow(Settings.gclaws.accreditation).to receive_messages(api_key:, origin:)

    WebMock.disable_net_connect!
  end

  describe '#post_icn_and_registration_combination' do
    let(:registration_number) { 'REG123456' }
    let(:post_url) { "#{api_url}/#{registration_number}" }

    context 'when the API call is successful' do
      before do
        stub_request(:post, post_url)
          .with(
            body: {
              icnNo: icn,
              registrationNo: registration_number,
              multiMatchInd: true
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 200,
            body: {
              icnNumber: icn,
              registrationNumbers: [registration_number]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns true' do
        result = subject.post_icn_and_registration_combination(icn, registration_number)
        expect(result).to be true
      end
    end

    context 'when the API returns a non-200 status code' do
      before do
        stub_request(:post, post_url)
          .with(
            body: {
              icnNo: icn,
              registrationNo: registration_number,
              multiMatchInd: true
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 400,
            body: { error: 'Bad Request' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns false' do
        result = subject.post_icn_and_registration_combination(icn, registration_number)
        expect(result).to be false
      end
    end

    context 'when the API returns no body' do
      before do
        stub_request(:post, post_url)
          .with(
            body: {
              icnNo: icn,
              registrationNo: registration_number,
              multiMatchInd: true
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 200,
            body: '',
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns false' do
        result = subject.post_icn_and_registration_combination(icn, registration_number)
        expect(result).to be false
      end
    end

    context 'when the API request raises an exception' do
      before do
        stub_request(:post, post_url)
          .with(
            body: {
              icnNo: icn,
              registrationNo: registration_number,
              multiMatchInd: true
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_raise(Faraday::ConnectionFailed.new('Connection failed'))
      end

      it 'logs the error and returns false' do
        # rubocop:disable Layout/LineLength
        expect(Rails.logger).to receive(:error).with(/Error posting ICN and registration combination: Connection failed/)
        # rubocop:enable Layout/LineLength
        result = subject.post_icn_and_registration_combination(icn, registration_number)
        expect(result).to be false
      end
    end

    context 'when parameters are blank' do
      it 'returns nil when ICN is blank' do
        result = subject.post_icn_and_registration_combination(nil, registration_number)
        expect(result).to be_nil

        expect(WebMock).not_to have_requested(:post, /#{Regexp.escape(api_url)}/)
      end

      it 'returns nil when registration_number is blank' do
        result = subject.post_icn_and_registration_combination(icn, nil)
        expect(result).to be_nil

        expect(WebMock).not_to have_requested(:post, /#{Regexp.escape(api_url)}/)
      end
    end
  end

  describe '#find_registration_numbers_for_icn' do
    context 'when the API returns registration numbers successfully' do
      before do
        stub_request(:post, api_url)
          .with(
            body: { icnNo: icn, multiMatchInd: true }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 200,
            body: {
              icnNumber: icn,
              registrationNumbers: %w[REG123456 REG789012]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the registration numbers' do
        result = subject.find_registration_numbers_for_icn(icn)
        expect(result).to eq(%w[REG123456 REG789012])
      end
    end

    context 'when the API returns an empty array of registration numbers' do
      before do
        stub_request(:post, api_url)
          .with(
            body: { icnNo: icn, multiMatchInd: true }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 200,
            body: {
              icnNumber: icn,
              registrationNumbers: []
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        result = subject.find_registration_numbers_for_icn(icn)
        expect(result).to be_nil
      end
    end

    context 'when the API returns a non-200 status code' do
      before do
        stub_request(:post, api_url)
          .with(
            body: { icnNo: icn, multiMatchInd: true }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 404,
            body: { error: 'Not Found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        result = subject.find_registration_numbers_for_icn(icn)
        expect(result).to be_nil
      end
    end

    context 'when the API returns invalid JSON' do
      before do
        stub_request(:post, api_url)
          .with(
            body: { icnNo: icn, multiMatchInd: true }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_return(
            status: 200,
            body: 'Not valid JSON',
            headers: { 'Content-Type': 'application/json' }
          )
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Error parsing OGC response/)
        result = subject.find_registration_numbers_for_icn(icn)
        expect(result).to be_nil
      end
    end

    context 'when the API request raises an exception' do
      before do
        stub_request(:post, api_url)
          .with(
            body: { icnNo: icn, multiMatchInd: true }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Origin' => origin,
              'x-api-key' => api_key
            }
          )
          .to_raise(Faraday::ConnectionFailed.new('Connection failed'))
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Error looking up registration number for ICN: Connection failed/)
        result = subject.find_registration_numbers_for_icn(icn)
        expect(result).to be_nil
      end
    end

    context 'when ICN is blank' do
      it 'returns nil without making API call' do
        result = subject.find_registration_numbers_for_icn(nil)
        expect(result).to be_nil

        expect(WebMock).not_to have_requested(:post, api_url)
      end
    end
  end
end
