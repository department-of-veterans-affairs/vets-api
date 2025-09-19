# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CredentialAttributesDigester do
  subject(:result) { described_class.new(credential_attributes:).perform }

  let(:credential_attributes) { attributes }
  let(:csp_email) { 'vets.gov.user+0@gmail.com' }

  let(:attributes) do
    {
      last_name: 'ALLEN',
      ssn: '796126859',
      birth_date: '1932-02-05',
      icn: '12324536V6347',
      email: csp_email,
      address: {
        street: 'Sesame Street',
        postal_code: '60131',
        state: 'IL',
        city: 'Franklin Park',
        country: 'USA'
      },
      idme_uuid: '88f572d491af46efa393cba6c351e252',
      logingov_uuid: nil,
      edipi: nil,
      first_name: 'HECTOR'
    }
  end

  describe '#perform' do
    context 'with a valid hash' do
      let(:expected_digest) { 'e7bbac99562da7b3a94929b615404438' }

      it 'returns the expected digest' do
        expect(result).to eq(expected_digest)
      end

      context 'when the hash order varies' do
        let(:credential_attributes) { attributes.to_a.reverse.to_h }

        it 'returns the same digest' do
          expect(result).to eq(expected_digest)
        end
      end

      context 'when an attribute value changes' do
        let(:csp_email) { 'new_email@example.com' }

        it 'returns a different digest' do
          expect(result).not_to eq(expected_digest)
        end
      end
    end

    context 'when credential_attributes is nil' do
      let(:credential_attributes) { nil }

      it { is_expected.to be_nil }
    end

    context 'when an error occurs' do
      let(:expected_log_message) { '[SignIn][CredentialAttributesDigester] Failed to digest user attributes' }
      let(:expected_log_payload) { { message: 'error' } }

      before do
        allow(Rails.logger).to receive(:error)
        allow(ActiveSupport::Digest).to receive(:hexdigest).and_raise(StandardError, 'error')
      end

      it 'logs and returns nil' do
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
      end
    end
  end
end
