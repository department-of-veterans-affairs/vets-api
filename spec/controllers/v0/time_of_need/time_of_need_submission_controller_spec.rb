# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::TimeOfNeed::TimeOfNeedSubmissionController, type: :controller do
  describe '#time-of-need-submit' do
    let(:controller_stub) { instance_double('V0::TimeOfNeed::TimeOfNeedSubmissionController') }
    it 'submits time of need information' do
      VCR.use_cassette('time_of_need/time_of_need_submission') do
        json = Hash.new
        json[:new_case] = { burial_activity_type: 'D', emblem_code: '55', cremains_type: 'I', remains_type: 'M'  }
        headers = { 'Content-Type': 'application/json', 'X-Key-Inflection': 'snake' }
        request.headers.merge! headers
        post :create, json
        expect(response.status).to eq 200
      end
    end
  end
end
