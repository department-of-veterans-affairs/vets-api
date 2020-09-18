# frozen_string_literal: true

require 'rails_helper'
require 'vet360/contact_information/transaction_response'

describe Vet360::ContactInformation::TransactionResponse do
  describe '.from' do
    subject { described_class.from(raw_response) }

    let(:raw_response) { OpenStruct.new(body: body) }

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
          'Vet360 transaction error',
          :error,
          { response_body: body },
          error: :vet360
        )
        subject
      end
    end
  end
end
