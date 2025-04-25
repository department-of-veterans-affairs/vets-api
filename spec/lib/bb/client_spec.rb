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
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
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

  context 'using legacy endpoints' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
      VCR.use_cassette 'bb_client/session' do
        @client ||= begin
          client = BB::Client.new(session: { user_id: '5751732' })
          client.authenticate
          client
        end
      end
    end

    # Need to pull the last updated to determine the staleness / freshness of the data
    # will revisit this later.
    it 'gets a list of extract statuses', :vcr do
      client_response = client.get_extract_status
      expect(client_response).to be_a(Common::Collection)
      expect(client_response.members.first).to be_a(ExtractStatus)
    end

    context 'with sentry enabled' do
      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      it 'logs failed extract statuses', :vcr do
        VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
          msg = 'Final health record refresh contained one or more error statuses'
          expect(Sentry).to receive(:set_extras).with({ refresh_failures: %w[Appointments ImagingStudy] })
          expect(Sentry).to receive(:capture_message).with(msg, level: 'warning')

          client.get_extract_status
        end
      end
    end

    # These are the list of eligible data classes that can be used to generate a report
    it 'gets a list of eligible data classes', :vcr do
      client_response = client.get_eligible_data_classes
      expect(client_response).to be_a(Common::Collection)
      expect(client_response.type).to eq(EligibleDataClass)
      expect(client_response.cached?).to be(true)
      expect(client_response.members).to all(respond_to(:name))
    end

    # This requests to generate a report. It just returns success, no file is returned.
    it 'generates a report', :vcr do
      params = {
        from_date: 10.years.ago.iso8601,
        to_date: Time.now.iso8601,
        data_classes: eligible_data_classes
      }
      client_response = client.post_generate(params)
      expect(client_response[:status]).to eq('OK')
    end

    # returns a PDF, it's binary but not a multipart
    it 'gets a pdf version of a report', :vcr do
      response_headers = {}
      header_cb = lambda do |headers|
        headers.each { |k, v| response_headers[k] = v }
      end
      response_stream = Enumerator.new do |stream|
        client.get_download_report('pdf', header_cb, stream)
      end
      response_stream.each { |_| }
      expect(response_headers['Content-Type']).to eq('application/pdf')
    end

    # this is just text in the response body
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

    describe 'Opting in to VHIE sharing' do
      context 'when the client is not already opted in', :vcr do
        it 'opts in without raising an error' do
          VCR.use_cassette('bb_client/opts_in_to_vhie_sharing') do
            expect { client.post_opt_in }.not_to raise_error
          end
        end
      end

      context 'when the client is already opted in', :vcr do
        it 'opts in again without raising an error' do
          VCR.use_cassette('bb_client/opts_in_to_vhie_sharing_while_opted_in') do
            expect { client.post_opt_in }.not_to raise_error
          end
        end
      end
    end

    describe 'Opting out of VHIE sharing' do
      context 'when the client is not already opted out', :vcr do
        it 'opts out without raising an error' do
          VCR.use_cassette('bb_client/opts_out_of_vhie_sharing') do
            expect { client.post_opt_out }.not_to raise_error
          end
        end
      end

      context 'when the client is already opted out', :vcr do
        it 'opts out again without raising an error' do
          VCR.use_cassette('bb_client/opts_out_of_vhie_sharing_while_opted_out') do
            expect { client.post_opt_out }.not_to raise_error
          end
        end
      end
    end

    it 'gets vhie sharing status', :vcr do
      client_response = client.get_status
      expect(client_response).to be_a(Hash)
      expect(client_response.key?(:consent_status)).to be(true)
      expect(client_response[:consent_status]).to eq('OPT-IN')
    end
  end
end
