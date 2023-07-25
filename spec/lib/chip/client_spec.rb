# frozen_string_literal: true

require 'rails_helper'
require 'chip/client'

describe Chip::Client do
  let(:test_username) { 'test_chip_user' }
  let(:test_password) { 'test_chip_password' }

  let(:client) { described_class.new(username: :test_username, password: :test_password) }

  describe '#initialize' do
    subject { described_class }

    context 'when username does not exist' do
      let(:expected_error) { ArgumentError }
      let(:expected_error_message) { 'Invalid username' }

      it 'raises a missing username validation error' do
        expect { subject.new(username: nil, password: :test_password) }.to raise_exception(expected_error,
                                                                                           expected_error_message)
      end
    end

    context 'when username is empty' do
      let(:expected_error) { ArgumentError }
      let(:expected_error_message) { 'Invalid username' }

      it 'raises a missing username validation error' do
        expect { subject.new(username: '', password: :test_password) }.to raise_exception(expected_error,
                                                                                          expected_error_message)
      end
    end

    context 'when password does not exist' do
      let(:expected_error) { ArgumentError }
      let(:expected_error_message) { 'Invalid password' }

      it 'raises a missing username validation error' do
        expect { subject.new(username: :test_username, password: nil) }.to raise_exception(expected_error,
                                                                                           expected_error_message)
      end
    end

    context 'when password is empty' do
      let(:expected_error) { ArgumentError }
      let(:expected_error_message) { 'Invalid password' }

      it 'raises a missing username validation error' do
        expect { subject.new(username: :test_username, password: '') }.to raise_exception(expected_error,
                                                                                          expected_error_message)
      end
    end

    context 'when username and password are valid' do
      it 'creates Chip::Client instance' do
        expect(subject.new(username: :test_username, password: :test_password)).to be_an_instance_of(Chip::Client)
      end
    end
  end

  describe 'configuration' do
    it 'is of type Configuration' do
      expect(client.class.configuration).to be_a(Chip::Configuration)
    end
  end

  describe 'perform_get_with_token' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'testToken' }
    let(:path) { '/testPath' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_return(response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:get).with(path).and_yield(Faraday::Request.new)
      client.perform_get_with_token(token:, path:)
    end

    it 'returns Faraday::Response' do
      expect(client.perform_get_with_token(token:, path:)).to be_a(Faraday::Response)
    end
  end

  describe 'perform_post_with_token' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'testToken' }
    let(:request_header) do
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => Settings.chip.api_gtwy_id.to_s,
        'Authorization' => "Bearer #{token}"
      }
    end
    let(:request) { Faraday::Request.new(request_header) }
    let(:path) { '/testPath' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_yield(request)
      client.perform_post_with_token(token:, path:)
    end

    it 'returns Faraday::Response' do
      expect(client.perform_post_with_token(token:, path:)).to be_a(Faraday::Response)
    end
  end

  describe 'token' do
    let(:chip_token_response) { Faraday::Response.new(body: { 'token' => 'testToken' }, status: 200) }
    let(:path) { '/token' }
    let(:claims_token) { Base64.encode64("#{test_username}:#{test_password}") }
    let(:request_header) do
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => Settings.chip.api_gtwy_id.to_s,
        'Authorization' => "Basic #{claims_token}"
      }
    end
    let(:request) { Faraday::Request.new(request_header) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with('/token').and_return(chip_token_response)
    end

    it 'calls Faraday::Connection' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_yield(request)
      client.token
    end

    it 'returns token' do
      expect(client.token).to eq(chip_token_response)
    end
  end
end
