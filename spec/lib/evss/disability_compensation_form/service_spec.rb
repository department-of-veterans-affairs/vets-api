# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  
  describe '#get_rated_disabilities' do
    let(:user) { build(:user, :loa3) }
    subject { described_class.new(user) }

    context 'with a valid evss response' do
      it 'returns an array of rated disabilities' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          response = subject.get_rated_disabilities
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
        end
      end
    end

    #this is intentionally vague until I know more
    context 'with an error' do
      it 'handles the error'
    end
  end

  describe '#submit_form' do
  end
end
