# frozen_string_literal: true

require 'rails_helper'
require 'pension_21p527ez/pension_military_information'
require 'va_profile/military_personnel/service_history_response'

RSpec.describe Pension21p527ez::PensionMilitaryInformation do
  let(:user) { build(:user, :loa3) }
  let(:army_episode) do
    VAProfile::Models::ServiceHistory.new(
      branch_of_service: 'Army'
    )
  end
  let(:unknown_episode) do
    VAProfile::Models::ServiceHistory.new(
      branch_of_service: 'Unknown'
    )
  end

  describe '#format_service_branches_for_pensions' do
    it 'returns an object of valid branches' do
      expect(described_class.new(user).format_service_branches_for_pensions(%w[
                                                                              army
                                                                              navy
                                                                              airForce
                                                                              coastGuard
                                                                              marineCorps
                                                                              spaceForce
                                                                              usphs
                                                                              noaa
                                                                            ])).to eq({
                                                                                        'army' => true,
                                                                                        'navy' => true,
                                                                                        'airForce' => true,
                                                                                        'coastGuard' => true,
                                                                                        'marineCorps' => true,
                                                                                        'spaceForce' => true,
                                                                                        'usphs' => true,
                                                                                        'noaa' => true
                                                                                      })
    end

    it 'filters out invalid branches' do
      expect(described_class.new(user).format_service_branches_for_pensions(['army', nil])).to eq({
                                                                                                    'army' => true
                                                                                                  })
    end
  end

  describe '#service_branches_for_pensions' do
    it 'returns an object of valid branches' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, episodes: [army_episode]
        )
      )
      expect(described_class.new(user).service_branches_for_pensions).to eq({
                                                                              'army' => true
                                                                            })
    end

    it 'filters out invalid branches' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, episodes: [unknown_episode]
        )
      )
      expect(described_class.new(user).service_branches_for_pensions).to eq({})
    end
  end
end
