# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/token_validation_client'
require_relative '../spec_helper'

describe AppealsApi::TokenValidationClient do
  let(:audience) { 'https://dev-api.va.gov/services/some-api' }
  let(:token) { 'ABC123' }
  let(:api_key) { 'abcd1234abcd1234abcd1234abcd1234abcd1234' }
  let(:client) { described_class.new(api_key:) }
  let(:veteran_icn) { '1012667145V762142' }
  let(:expected_scopes) { %w[veteran/something.read] }
  let(:token_scopes) { expected_scopes }
  let(:valid) { true }

  describe '#validate_token!' do
    let(:result) do
      with_openid_auth(token_scopes, valid:) do
        client.validate_token!(audience:, token:, scopes: expected_scopes)
      end
    end

    context 'with a valid veteran token' do
      it 'indicates the token is valid and returns correct details' do
        expect(result.scopes).to eq token_scopes
        expect(result.veteran_icn).to eq veteran_icn
      end
    end

    context 'with a valid representative token' do
      let(:expected_scopes) { %w[representative/something.read] }

      it 'indicates the token is valid and returns correct details' do
        expect(result.scopes).to eq token_scopes
        expect(result.veteran_icn).to be_nil
      end
    end

    context 'with a valid system token' do
      let(:expected_scopes) { %w[system/something.read] }

      it 'indicates the token is valid and returns correct details' do
        expect(result.scopes).to eq token_scopes
        expect(result.veteran_icn).to be_nil
      end
    end

    context 'with an invalid token' do
      let(:valid) { false }

      it 'raises an Unauthorized error' do
        expect { result }.to raise_error Common::Exceptions::Unauthorized
      end
    end

    context 'without the expected scope(s)' do
      let(:token_scopes) { %w[not-the-right-scope] }

      it 'raises a Forbidden error' do
        expect { result }.to raise_error Common::Exceptions::Forbidden
      end
    end
  end
end
