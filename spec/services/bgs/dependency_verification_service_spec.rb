# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependencyVerificationService do
  let(:user) { create(:evss_user, :loa3) }

  describe '#read_diaries' do
    it 'returns dependency decisions that all contain :award_effective_date key' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)
        dependency_decisions = service.read_diaries[:dependency_decs]

        result = dependency_decisions.all? do |dependency_decision|
          dependency_decision.key?(:award_effective_date)
        end

        expected = true

        expect(result).to eq expected
      end
    end

    it 'retuns an empty response if participant id is nil' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return(nil)
        service = BGS::DependencyVerificationService.new(user)
        diaries = service.read_diaries

        expect(diaries).to eq({ dependency_decs: nil, diaries: [] })
      end
    end

    it 'does not include any dependency decisions that are in the future' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)

        Timecop.freeze(Time.zone.local(1990))

        dependency_decisions = service.read_diaries[:dependency_decs]

        result = dependency_decisions.all? do |dependency_decision|
          dependency_decision[:award_effective_date]&.past?
        end

        expected = true

        expect(result).to eq expected

        Timecop.return
      end
    end

    it 'does not include any dependency decisions that are NAWDDEP' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)
        dependency_decisions = service.read_diaries[:dependency_decs]

        result = dependency_decisions.none? do |dependency_decision|
          dependency_decision[:dependency_status_type] == 'NAWDDEP'
        end

        expected = true

        expect(result).to eq expected
      end
    end

    it 'does not include more than one dependecy decision per person_id' do
      VCR.use_cassette('bgs/diaries_service/read_diaries') do
        allow(user).to receive(:participant_id).and_return('13014883')
        service = BGS::DependencyVerificationService.new(user)
        dependency_decisions = service.read_diaries[:dependency_decs]

        person_ids = dependency_decisions.pluck(:person_id)
        result = person_ids == person_ids.uniq

        expected = true

        expect(result).to eq expected
      end
    end

    it 'returns an empty response when it cannot find records' do
      VCR.use_cassette('bgs/diaries_service/read_empty_diaries') do
        allow(user).to receive(:participant_id).and_return('123')

        service = BGS::DependencyVerificationService.new(user)
        diaries = service.read_diaries
        expect(diaries[:diaries]).to eq([])
        expect(diaries[:dependency_decs]).to match(
          a_hash_including(
            award_type: 'CPL',
            beneficiary_id: '123',
            dependency_decision_id: '123',
            modified_location: '101'
          )
        )
      end
    end
  end
end
