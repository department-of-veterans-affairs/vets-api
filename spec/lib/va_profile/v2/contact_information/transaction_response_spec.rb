# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/v2/contact_information/transaction_response'

describe VAProfile::V2::ContactInformation::TransactionResponse do
  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
  end

  describe '.from' do
    subject { described_class.from(raw_response) }

    let(:raw_response) { OpenStruct.new(body:) }

    describe VAProfile::V2::ContactInformation::AddressTransactionResponse do
      let(:body) do
        {
          'tx_audit_id' => 'a2af8cd1-472c-4e6f-bd5a-f95e31e351b7',
          'status' => 'COMPLETED_SUCCESS',
          'tx_status' => 'COMPLETED_SUCCESS',
          'tx_output' => [
            {
              'address_pou' => ''
            }
          ]
        }
      end

      context 'with a residence address change' do
        before do
          body['tx_output'][0]['address_pou'] = VAProfile::Models::V3::BaseAddress::RESIDENCE
        end

        it 'has the correct changed field' do
          expect(subject.changed_field).to eq(:residence_address)
        end
      end

      context 'with a correspondence address change' do
        before do
          body['tx_output'][0]['address_pou'] = VAProfile::Models::V3::BaseAddress::CORRESPONDENCE
        end

        it 'has the correct changed field' do
          expect(subject.changed_field).to eq(:correspondence_address)
        end
      end
    end

    describe VAProfile::V2::ContactInformation::TelephoneTransactionResponse do
      let(:body) do
        {
          'tx_audit_id' => 'a2af8cd1-472c-4e6f-bd5a-f95e31e351b7',
          'status' => 'COMPLETED_SUCCESS',
          'tx_status' => 'COMPLETED_SUCCESS',
          'tx_output' => [
            {
              'phone_type' => ''
            }
          ]
        }
      end

      context 'with a mobile phone change' do
        before do
          body['tx_output'][0]['phone_type'] = 'MOBILE'
        end

        it 'has the correct changed field' do
          expect(subject.changed_field).to eq(:mobile_phone)
        end
      end

      context 'with a home phone change' do
        before do
          body['tx_output'][0]['phone_type'] = 'HOME'
        end

        it 'has the correct changed field' do
          expect(subject.changed_field).to eq(:home_phone)
        end
      end

      context 'with a work phone change' do
        before do
          body['tx_output'][0]['phone_type'] = 'WORK'
        end

        it 'has the correct changed field' do
          expect(subject.changed_field).to eq(:work_phone)
        end
      end
    end

    describe VAProfile::V2::ContactInformation::EmailTransactionResponse do
      let(:body) do
        { 'tx_audit_id' => 'cb99a754-9fa9-4f3c-be93-ede12c14b68e',
          'status' => 'COMPLETED_SUCCESS',
          'tx_status' => 'COMPLETED_SUCCESS',
          'tx_type' => 'PUSH',
          'tx_interaction_type' => 'ATTENDED',
          'tx_push_input' => {
            'email_id' => 8087, 'email_address_text' => 'person43@example.com',
            'source_date' => '2020-01-16T03:11:59Z',
            'originating_source_system' => 'VETSGOV', 'source_system_user' => '1234', 'vet360_id' => 1
          },
          'tx_output' =>
          [{ 'email_id' => 8087,
             'email_address_text' => 'person43@example.com',
             'create_date' => '2018-09-06T17:49:03Z',
             'update_date' => '2020-01-16T03:12:00Z',
             'tx_audit_id' => 'cb99a754-9fa9-4f3c-be93-ede12c14b68e',
             'source_system' => 'VETSGOV',
             'source_date' => '2020-01-16T03:11:59Z',
             'originating_source_system' => 'VETSGOV',
             'source_system_user' => '1234',
             'effective_start_date' => '2020-01-16T03:11:59.000Z',
             'vet360_id' => 1 }] }
      end

      describe '#new_email' do
        context 'without an effective_end_date' do
          it 'returns the email' do
            expect(subject.new_email).to eq('person43@example.com')
          end
        end

        context 'with an effective_end_date' do
          before do
            body['tx_output'][0]['effective_end_date'] = '2020-01-16T03:11:59.000Z'
          end

          it 'returns nil' do
            expect(subject.new_email).to be_nil
          end
        end
      end
    end

    describe VAProfile::V2::ContactInformation::PersonTransactionResponse do
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
        redacted_response_body = described_class.redact_response_body(body)

        expect(described_class).to receive(:log_message_to_sentry).with(
          'VAProfile transaction error',
          :error,
          { response_body: redacted_response_body },
          error: :va_profile
        )
        subject
      end
    end
  end
end
