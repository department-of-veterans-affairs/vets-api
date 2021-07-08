# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependencyVerificationService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:payload_keys) do
    %i[
      award_event_id
      award_type
      begin_award_event_id
      beneficiary_id
      decision_id
      dependency_decision_id
      first_name
      full_name
      last_name
      modified_action
      modified_by
      modified_location
      modified_process
      person_id
      social_security_number
      sort_date
      sort_order_number
      veteran_id
      veteran_indicator
    ]
  end

  describe '#read_diaries' do
    it 'returns diary information given a user\'s participant_id' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)
        diaries = service.read_diaries

        expect(diaries[:dependency_decs].size).to be > 2
        expect(diaries[:dependency_decs].first.keys).to eq(payload_keys)
      end
    end

    it 'returns dependency decisions that all contain :award_effective_date key' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)
        dependency_decisions = service.read_diaries[:dependency_decs]

        result = dependency_decisions.all? do |dependency_decision|
          dependency_decision.has_key?(:award_effective_date)
        end

        expected = true

        expect(result).to eq expected
      end
    end

    xit 'should not include any dependency decisions that are in the future' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)

        Timecop.freeze(Time.now - 50.years)

        dependency_decisions = service.read_diaries[:dependency_decs]

        result = dependency_decisions.all? do |dependency_decision|
          dependency_decision[:award_effective_date]&.past?
        end

        expected = true

        expect(result).to eq expected

        Timecop.return
      end
    end

    xit 'should not include more than one dependecy decision per person_id' do
    end

    xit 'should not include any dependency decisions that are NAWDDEP' do
    end

    it 'returns an empty response when it cannot find records' do
      VCR.use_cassette('bgs/diaries_service/read_empty_diaries') do
        allow(user).to receive(:participant_id).and_return('123')

        service = BGS::DependencyVerificationService.new(user)
        diaries = service.read_diaries
        expect(diaries[:diaries]).to eq([])
        expect(diaries[:dependency_decs]).to match([
                                                     a_hash_including(
                                                       award_type: 'CPL',
                                                       beneficiary_id: '123',
                                                       dependency_decision_id: '123',
                                                       modified_location: '101'
                                                     )
                                                   ])
      end
    end
  end
end
