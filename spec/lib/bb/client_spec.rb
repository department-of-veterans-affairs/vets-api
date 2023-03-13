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

  before(:all) do
    VCR.use_cassette 'bb_client/session', record: :new_episodes do
      @client ||= begin
        client = BB::Client.new(session: { user_id: '12210827' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

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
        expect(Raven).to receive(:extra_context).with({ refresh_failures: %w[Appointments ImagingStudy] })
        expect(Raven).to receive(:capture_message).with(msg, level: 'warning')

        client.get_extract_status
      end
    end
  end

  # These are the list of eligible data classes that can be used to generate a report
  it 'gets a list of eligible data classes', :vcr do
    client_response = client.get_eligible_data_classes
    expect(client_response).to be_a(Common::Collection)
    expect(client_response.type).to eq(EligibleDataClass)
    expect(client_response.cached?).to eq(true)
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
end
