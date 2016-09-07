require 'rails_helper'
require 'savon/mock/spec_helper'
require 'mvi/service'

describe MVI::Service do
  include Savon::SpecHelper

  before(:all) { savon.mock!   }
  after(:all)  { savon.unmock! }

  describe ".find_candidate" do
    it "authenticates the user with the service" do
      message = MVI::Messages::FindCandidateMessage.build(vcid, first_name, last_name, dob, ssn)
      expected = File.read("spec/support/mvi/find_candidate_response.xml")

      # set up an expectation
      savon.expects(MVI::Messages::FindCandidateMessage::EXTENSION).with(message: message).returns(expected)

      # call the service
      response = MVI::Service.find_candidate(vcid, first_name, last_name, dob, ssn)

      expect(response).to be_successful
    end
  end
end
