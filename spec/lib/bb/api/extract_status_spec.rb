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

  # It's not at all clear to me what extract statuses are. The documentation says:
  # "The purpose of this call is to allow callers to request a PHR refresh"
  # What is this, and how is it useful?
  # The output looks something like this:
  # {"facilityExtractStatusList":
  # [
  # {
  # "extractType":"ChemistryHematology",
  # "lastUpdated":1395945131697,
  # "inProgress":true,
  # "createdOn":1402939469774,
  # "facility":null
  # },
  # {
  # "extractType":"DodMilitaryService",
  # "lastUpdated":1395945131697,
  # "inProgress":true,
  # "createdOn":1402939469774,
  # "facility":null
  # }, ...
  # Not sure what this is to be user for exactly.
  it 'gets a list of extract statuses', :vcr do
    client_response = client.get_extract_status
    expect(client_response).to be_a(Common::Collection)
    expect(client_response.members.first).to be_a(ExtractStatus)
  end

  # These are the list of eligible data classes, pulling this list would allow_blank
  # the front end to determine what reports can be selected to comprise the generated
  # report. This is sort of like the equivalent of "categories" for secure messaging, only
  # rather than being unique for all users, it is unique to each user and dependent on the
  # types of medical services or medical history that they have available.
  it 'gets a list of eligible data classes', :vcr do
    client_response = client.get_eligible_data_classes
    expect(client_response).to be_a(EligibleDataClasses)
    expect(client_response.data_classes).to be_an(Array)
    expect(client_response.data_classes).to all(be_a(String))
    expect(client_response.id).to eq('c07a392ac00e579fddd2910869b42379')
  end

  # This generates a report. It just returns success, does not return the actual report
  # itself. There is no ID returned either, so from this one can only surmise, that a
  # generated report would overwrite any previously generated reports.
  # So one question that comes up is, lets say I have a report that is the full consolidated
  # report comrising all data classes. When i pull the PDF or text versions of this report
  # I'm getting the longest report possible based on the data classes I have eligible.
  # Now, I decide I just want a report with my prescription history. If i pass only prescriptions
  # as the data classes param, when i later request the PDF or text version of my report,
  # do I only get prescriptions?
  # Why doesn't this instead return an ID that can be used to track the specific resource
  # that was requested, and the get download report would accept that id as a parameter?
  # perhaps passing no id would default to returning the consolidated report with all eligible
  # data classes.
  it 'generates a report', :vcr do
    params = {
      from_date: 10.years.ago.iso8601,
      to_date: Time.now.iso8601,
      data_classes: eligible_data_classes
    }
    client_response = client.post_generate(params)
  end

  # returns a PDF, it's binary but not necessarily a multipart
  it 'gets a pdf version of a report', :vcr do
    client_response = client.get_download_report('pdf')
  end

  # this is just text in the response body
  it 'gets a text version of a report', :vcr do
    client_response = client.get_download_report('txt')
  end

  # This doesn't work at all and returns an error, but it is in the documentation
  # so would like to get some further clarfication on what this could be.
  it 'gets a bluebutton version of a report', :vcr do
    client_response = client.get_download_report('bluebutton')
  end
end
