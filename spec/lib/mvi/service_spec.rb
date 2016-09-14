require 'rails_helper'
require 'savon/mock/spec_helper'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'

describe MVI::Service do
  include Savon::SpecHelper

  before(:all) { savon.mock! }
  after(:all)  { savon.unmock! }

  let(:first_name) { 'John' }
  let(:last_name) { 'Smith' }
  let(:dob) { Time.new(1980, 1, 1) }
  let(:ssn) { '555-44-3333' }

  describe ".find_candidate" do
    it "calls the prpa_in201305_uv02 endpoint with a find candidate message" do
      message = MVI::Messages::FindCandidateMessage.build(first_name, last_name, dob, ssn)
      expected = File.read("#{ENV['MVI_FILE_PATH']}/spec/support/find_candidate_response.xml")
      savon.expects(:prpa_in201305_uv02).with(xml: message).returns(expected)
      response = MVI::Service.find_candidate(first_name, last_name, dob, ssn)
      expect(response).to be_successful
    end
  end
end
