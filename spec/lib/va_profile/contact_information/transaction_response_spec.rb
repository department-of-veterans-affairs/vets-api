# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/contact_information/transaction_response'

describe VAProfile::ContactInformation::TransactionResponse do
  describe '.from' do
    subject { described_class.from(raw_response) }

    let(:raw_response) { OpenStruct.new(body: body) }

    describe VAProfile::ContactInformation::PersonTransactionResponse do
      context 'with a MVI201 response error' do
        let(:body) do
          {
            'status' => 'COMPLETED_SUCCESS',
            'tx_audit_id' => '3b4633be-dc81-4cb9-874a-b9fc06fb4e21',
            'tx_interaction_type' => 'ATTENDED',
            'tx_messages' => [
              {
                'code' => 'MVI201',
                'key' => 'MVI not found',
                'potentially_self_correcting_on_retry' => false,
                'severity' => 'ERROR',
                'text' => 'The person with the identifier requested was not found in MVI.'
              }
            ],
            'tx_status' => 'COMPLETED_FAILURE'
          }
        end
        let(:user) { build(:user, :loa3) }

        it 'logs that error to sentry' do
          allow(described_class).to receive(:log_message_to_sentry)
          expect(described_class).to receive(:log_message_to_sentry).with(
            'va profile mpi not found',
            :error,
            {
              icn: user.icn,
              edipi: user.edipi,
              response_body: raw_response.body
            },
            error: :va_profile
          )
          described_class.from(raw_response, user)
        end
      end
    end

    context 'with a response error' do
      let(:body) do
        { 'tx_audit_id' => '1a44d122-176e-45a2-8726-083e89fdeb15',
          'status' => 'COMPLETED_SUCCESS',
          'tx_status' => 'COMPLETED_FAILURE',
          'tx_type' => 'PUSH',
          'tx_interaction_type' => 'ATTENDED',
          'tx_push_input' =>
          { 'source_date' => '2020-03-18T14:10:54Z',
            'originating_source_system' => 'VETSGOV',
            'source_system_user' => '1013127592V828553',
            'effective_start_date' => '2020-03-18T14:10:54Z',
            'vet360_id' => 137_161,
            'address_id' => 107_667,
            'address_type' => 'DOMESTIC',
            'address_pou' => 'CORRESPONDENCE',
            'address_line1' => 'sdfsdf',
            'city_name' => 'San Francisco',
            'state_code' => 'CA',
            'zip_code5' => '94122',
            'county' => {},
            'country_name' => 'United States',
            'country_code_iso3' => 'USA' },
          'tx_messages' =>
          [
            {
              'code' => 'ADDRVAL112',
              'key' => 'addressBio.AddressCouldNotBeFound',
              'text' => 'The Address could not be found',
              'severity' => 'ERROR'
            },
            {
              'code' => 'ADDR306',
              'key' => 'addressBio.lowConfidenceScore',
              'text' => 'VaProfile Validation Failed: Confidence Score less than 80',
              'severity' => 'ERROR'
            },
            {
              'code' => 'ADDR305',
              'key' => 'addressBio.deliveryPointNotConfirmed',
              'text' => 'VaProfile Validation Failed: Delivery Point is Not Confirmed for Domestic Residence',
              'severity' => 'ERROR'
            }
          ] }
      end

      it 'logs that error to sentry' do
        expect(described_class).to receive(:log_message_to_sentry).with(
          'VAProfile transaction error',
          :error,
          { response_body: body },
          error: :va_profile
        )
        subject
      end
    end
  end
end
