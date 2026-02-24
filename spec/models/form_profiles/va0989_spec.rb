# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA0989 do
  subject(:profile) { described_class.new(form_id: '22-0989', user: build(:user)) }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({ version: 0, prefill: true, returnUrl: '/applicant/information' })
    end
  end

  describe '#prefill' do
    before do
      allow_any_instance_of(BGS::People::Service).to(
        receive(:find_person_by_participant_id).and_return(BGS::People::Response.new({ file_nbr: '123456789' }))
      )
      allow_any_instance_of(User).to(
        receive(:participant_id).and_return('600061742')
      )
    end

    it 'prefills form data' do
      VCR.use_cassette('lighthouse/direct_deposit/show/200_valid_new_icn') do
        data = profile.prefill
        expect(data[:form_data]['applicantName']).to eq({ 'first' => 'Abraham',
                                                          'last' => 'Lincoln' })
        expect(data[:form_data]['ssn']).to eq('796111863')
        expect(data[:form_data]['vaFileNumber']).to eq('123456789')
      end
    end
  end
end
