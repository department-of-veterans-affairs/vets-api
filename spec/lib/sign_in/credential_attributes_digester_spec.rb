# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/credential_attributes_digester'

RSpec.describe SignIn::CredentialAttributesDigester do
  subject(:digester) do
    described_class.new(credential_uuid:, first_name:, last_name:, ssn:, birth_date:, email:)
  end

  let(:credential_uuid) { '5bfd88a0-e61d-4427-80e1-211b2b61ad6f' }
  let(:first_name) { 'HECTOR' }
  let(:last_name) { 'ALLEN' }
  let(:ssn) { '796126859' }
  let(:birth_date) { '1932-02-05' }
  let(:email) { 'test@email.com' }

  let(:pepper) { '5740e000be940493231f85324c413bd2' }

  before do
    allow(IdentitySettings.sign_in.credential_attributes_digester).to receive(:pepper).and_return(pepper)
  end

  describe 'validations' do
    context 'when all attributes are present and valid' do
      it { is_expected.to be_valid }
    end

    context 'when credential_uuid is missing' do
      let(:credential_uuid) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when last_name is missing' do
      let(:last_name) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when birth_date is missing' do
      let(:birth_date) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when email is missing' do
      let(:email) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when pepper is not configured' do
      let(:pepper) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  describe '#perform' do
    context 'with valid attributes' do
      let(:expected_digest) { '626deaddbf14a3697aabcad66770ca0fd24638f7bca5d3380694c3e6c3f41e5b' }

      it 'returns the expected digest' do
        expect(digester.perform).to eq(expected_digest)
      end

      context 'when an attribute value changes' do
        let(:email) { 'new_email@example.com' }

        it 'returns a different digest' do
          expect(digester.perform).not_to eq(expected_digest)
        end
      end
    end

    context 'when an error occurs' do
      let(:expected_log_message) { '[SignIn][CredentialAttributesDigester] Failed to digest user attributes' }
      let(:expected_log_payload) { { message: 'error' } }

      before do
        allow(Rails.logger).to receive(:info)
        allow(OpenSSL::HMAC).to receive(:hexdigest).and_raise(StandardError, 'error')
      end

      it 'logs and returns nil' do
        expect(digester.perform).to be_nil
        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
      end
    end
  end
end
