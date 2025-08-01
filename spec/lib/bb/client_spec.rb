# frozen_string_literal: true

require 'rails_helper'
require 'bb/client'

describe 'bb client' do
  let(:eligible_data_classes) do
    %w[ seiactivityjournal seiallergies seidemographics familyhealthhistory
        seifoodjournal healthcareproviders healthinsurance seiimmunizations
        labsandtests medicalevents medications militaryhealthhistory
        seimygoalscurrent seimygoalscompleted treatmentfacilities
        vitalsandreadings prescriptions medications vaallergies
        vaadmissionsanddischarges futureappointments pastappointments
        vademographics vaekg vaimmunizations vachemlabs vaprogressnotes
        vapathology vaproblemlist varadiology vahth wellness dodmilitaryservice ]
  end

  let(:client) { @client }

  context 'using API Gateway endpoints' do
    before do
      VCR.use_cassette 'bb_client/apigw_session' do
        @client ||= begin
          client = BB::Client.new(session: { user_id: '21207668' })
          client.authenticate
          client
        end
      end
    end

    context 'with sentry enabled' do
      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      it 'logs failed extract statuses', :vcr do
        VCR.use_cassette('bb_client/apigw_gets_a_list_of_extract_statuses') do
          msg = 'Final health record refresh contained one or more error statuses'
          expect(Sentry).to receive(:set_extras).with({ refresh_failures: %w[Appointments ImagingStudy] })
          expect(Sentry).to receive(:capture_message).with(msg, level: 'warning')

          client.get_extract_status
        end
      end

      it 'gets a text version of a report', :vcr do
        response_headers = {}
        header_cb = lambda do |headers|
          headers.each { |k, v| response_headers[k] = v }
        end
        response_stream = Enumerator.new do |stream|
          client.get_download_report('txt', header_cb, stream)
        end
        response_stream.each { |_| }
        expect(response_headers['Content-Type']).to eq('text/plain')
      end
    end

    describe 'Opting out of VHIE sharing' do
      context 'when the client is not already opted out', :vcr do
        it 'opts out without raising an error' do
          VCR.use_cassette('bb_client/apigw_opts_out_of_vhie_sharing') do
            expect { client.post_opt_out }.not_to raise_error
          end
        end
      end
    end
  end
end
