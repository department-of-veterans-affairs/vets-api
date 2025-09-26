# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/credential_attributes_digester'

RSpec.describe SignIn::CredentialAttributesDigester do
  subject(:digester) { described_class.new(credential_attributes:) }

  let(:csp_email) { 'vets.gov.user+0@gmail.com' }

  let(:credential_attributes) do
    {
      last_name: 'ALLEN',
      ssn: '796126859',
      birth_date: '1932-02-05',
      icn: '12324536V6347',
      email: csp_email,
      address:,
      idme_uuid: '88f572d491af46efa393cba6c351e252',
      edipi: nil,
      first_name: 'HECTOR'
    }
  end

  let(:address) do
    {
      street: 'Sesame Street',
      postal_code: '60131',
      state: 'IL',
      city: 'Franklin Park',
      country: 'USA'
    }
  end

  describe '#perform' do
    context 'with a valid hash' do
      let(:expected_digest) {  'ac2b7fd26886c11a0fa70810b92d3e1b' }

      it 'returns the expected digest' do
        expect(digester.perform).to eq(expected_digest)
      end

      context 'when the hash order is different' do
        let(:credential_attributes) do
          {
            first_name: 'HECTOR',
            last_name: 'ALLEN',
            ssn: '796126859',
            birth_date: '1932-02-05',
            icn: '12324536V6347',
            email: csp_email,
            address:,
            idme_uuid: '88f572d491af46efa393cba6c351e252',
            edipi: nil
          }
        end

        it 'returns the same digest' do
          expect(digester.perform).to eq(expected_digest)
        end

        context 'when the nested hash order is different' do
          let(:address) do
            {
              country: 'USA',
              city: 'Franklin Park',
              state: 'IL',
              postal_code: '60131',
              street: 'Sesame Street'
            }
          end

          it 'returns the same digest' do
            expect(digester.perform).to eq(expected_digest)
          end
        end
      end

      context 'when an attribute value changes' do
        let(:csp_email) { 'new_email@example.com' }

        it 'returns a different digest' do
          expect(digester.perform).not_to eq(expected_digest)
        end
      end
    end

    context 'when credential_attributes is nil' do
      let(:credential_attributes) { nil }

      it 'returns nil' do
        expect(digester.perform).to be_nil
      end
    end

    context 'when an error occurs' do
      let(:expected_log_message) { '[SignIn][CredentialAttributesDigester] Failed to digest user attributes' }
      let(:expected_log_payload) { { message: 'error' } }

      before do
        allow(Rails.logger).to receive(:error)
        allow(ActiveSupport::Digest).to receive(:hexdigest).and_raise(StandardError, 'error')
      end

      it 'logs and returns nil' do
        expect(digester.perform).to be_nil
        expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
      end
    end
  end
end
