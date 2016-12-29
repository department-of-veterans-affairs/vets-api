# frozen_string_literal: true
require 'rails_helper'
require 'bb/client'

describe 'bb client' do
  let(:eligible_data_classes) do
    %w( seiactivityjournal seiallergies seidemographics familyhealthhistory
        seifoodjournal healthcareproviders healthinsurance seiimmunizations
        labsandtests medicalevents medications militaryhealthhistory
        seimygoalscurrent seimygoalscompleted treatmentfacilities
        vitalsandreadings prescriptions medications vaallergies
        vaadmissionsanddischarges futureappointments pastappointments
        vademographics vaekg vaimmunizations vachemlabs vaprogressnotes
        vapathology vaproblemlist varadiology vahth wellness dodmilitaryservice )
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

  it 'gets a list of extract statuses', :vcr do
    client_response = client.get_extract_status
    expect(client_response).to be_a(Common::Collection)
    expect(client_response.members.first).to be_a(ExtractStatus)
  end

  it 'gets a list of eligible data classes', :vcr do
    client_response = client.get_eligible_data_classes
    expect(client_response).to be_a(EligibleDataClasses)
    expect(client_response.data_classes).to be_an(Array)
    expect(client_response.data_classes).to all(be_a(String))
    expect(client_response.id).to eq('c07a392ac00e579fddd2910869b42379')
  end

  it 'generates a report', :vcr do
    params = {
      from_date: 10.years.ago.iso8601,
      to_date: Time.now.iso8601,
      data_classes: eligible_data_classes
    }
    client_response = client.post_generate(params)
  end

  it 'gets a pdf version of a report', :vcr do
    client_response = client.get_download_report('pdf')
  end

  it 'gets a text version of a report', :vcr do
    client_response = client.get_download_report('txt')
  end

  it 'gets a bluebutton version of a report', :vcr do
    client_response = client.get_download_report('bluebutton')
  end
end
