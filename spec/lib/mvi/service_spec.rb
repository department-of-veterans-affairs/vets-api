require 'rails_helper'
require 'savon/mock/spec_helper'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'

describe MVI::Service do
  include Savon::SpecHelper

  before(:all) { savon.mock! }
  after(:all)  { savon.unmock! }

  let(:vcid) { 'abc123' }
  let(:first_name) { 'john' }
  let(:last_name) { 'smith' }
  let(:dob) { Time.new(1980, 1, 1) }
  let(:ssn) { '555-43-2222' }

  describe ".find_candidate" do
    it "authenticates the user with the service" do
      message_builder = MVI::Messages::FindCandidateMessage.new
      message = message_builder.build(vcid, first_name, last_name, dob, ssn)
      expected = File.read('spec/support/mvi/find_candidate_response.xml')
      savon.expects(MVI::Messages::FindCandidateMessage::EXTENSION).with(message: message).returns(expected)
      response = MVI::Service.find_candidate(vcid, first_name, last_name, dob, ssn)
      expect(response).to be_successful
    end
  end
end
