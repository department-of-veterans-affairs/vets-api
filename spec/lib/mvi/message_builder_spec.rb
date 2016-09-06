require 'rails_helper'
require 'mvi/messages/find_candidate_message'

describe MVI::Messages::FindCandidateMessage do
  describe 'header' do
    it 'should generate a valid header' do
      expect(
        message.build('123456789', 'John', 'Smith', Date.new(1980, 1, 1), '555-11-4477')
      ).to eq('xml') # TODO(AJD): validate against xsd
    end
  end
end
