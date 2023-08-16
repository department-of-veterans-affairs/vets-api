# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::IdmePublicKeyFetcher do
  describe '#perform' do
    subject { SignIn::IdmePublicKeyFetcher.new.perform }

    around { |example| VCR.use_cassette(idme_response, &example) }

    context 'when it succeeds' do
      let(:idme_response) { 'identity/idme_200_responses' }

      it 'returns one or more public keys' do
        expect(subject.first).to be_public
      end
    end

    context 'when it fails to connect to the ID.me public keys endpoint' do
      let(:idme_response) { 'identity/idme_404_response' }
      let(:expected_error_message) { 'Failed to connect to ID.me public certificates endpoint' }

      it 'raises a PublicKeyError' do
        expect { subject }.to raise_error(SignIn::Idme::Errors::PublicKeyError, expected_error_message)
      end
    end

    context 'when it fails to find any RS256 keys' do
      let(:idme_response) { 'identity/idme_no_rs256_key_response' }
      let(:expected_error_message) { 'No ID.me RS256 public key found' }

      it 'raises a PublicKeyError with a message that no RS256 key was found' do
        expect { subject }.to raise_error(SignIn::Idme::Errors::PublicKeyError, expected_error_message)
      end
    end
  end
end
