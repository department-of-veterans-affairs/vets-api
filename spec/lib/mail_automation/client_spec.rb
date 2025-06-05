# frozen_string_literal: true

require 'rails_helper'
require 'mail_automation/client'

RSpec.describe MailAutomation::Client do
  let(:claim_id) { 1234 }
  let(:file_number) { 1234 }
  let(:client) do
    MailAutomation::Client.new(
      form526: {
        form526: {
          form526: {
            disabilities: [{
              name: 'sleep apnea',
              diagnosticCode: 6847
            }]
          }
        },
        form4142: {
          privacyAgreementAccepted: true,
          email: 'test@example.com'
        },
        form0781: nil,
        form526_uploads: [
          {
            name: 'test_filename.pdf',
            confirmationCode: '01234567-89ab-cdef-0123-456789abcdef',
            attachmentId: 'L023',
            size: 9876,
            isEncrypted: false
          }
        ]
      }.as_json,
      file_number:,
      claim_id:
    )
  end

  describe 'making requests' do
    let(:bearer_token_object) { double('bearer response', body: { 'access_token' => 'blah' }) }

    context 'valid requests' do
      let(:generic_response) do
        double('mail automation response', status: 200, body: { packetId: '12345' }.as_json)
      end
      let(:flipper_enabled) { true }

      before do
        allow(client).to receive_messages(perform: generic_response, authenticate: bearer_token_object)
        allow(Flipper).to receive(:enabled?).with(:disability_526_send_mas_all_ancillaries).and_return(flipper_enabled)
      end

      it 'sets the headers to include the bearer token' do
        response = client.initiate_apcas_processing
        expect(response.body['packetId']).to eq '12345'
      end

      context 'when sending all ancillaries is turned on' do
        let(:flipper_enabled) { true }

        it 'includes form 526 uploads' do
          client.initiate_apcas_processing
          expect(client).to have_received(:perform) do |_method, _path, params, _headers, _options|
            expect(JSON.parse(params)['form526_uploads'][0]).to include(
              'name' => 'test_filename.pdf',
              'size' => 9876
            )
          end
        end

        it 'includes forms 4142 and 0781' do
          client.initiate_apcas_processing
          expect(client).to have_received(:perform) do |_method, _path, params, _headers, _options|
            expect(JSON.parse(params)).to include(
              'form4142' => { 'privacyAgreementAccepted' => true, 'email' => 'test@example.com' },
              'form0781' => nil
            )
          end
        end
      end

      context 'when sending all ancillaries is turned off' do
        let(:flipper_enabled) { false }

        it 'excludes forms 4142 and 0781' do
          client.initiate_apcas_processing
          expect(client).to have_received(:perform) do |_method, _path, params, _headers, _options|
            params = JSON.parse(params)
            expect(params).not_to have_key('form4142')
            expect(params).not_to have_key('form0781')
          end
        end
      end
    end

    context 'unsuccessful requests' do
    end
  end
end
