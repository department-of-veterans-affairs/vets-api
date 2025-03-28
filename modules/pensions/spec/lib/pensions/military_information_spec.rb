# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/military_personnel/service_history_response'

RSpec.describe Pensions::MilitaryInformation do
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
      branches = %w[army navy airForce coastGuard marineCorps spaceForce usphs noaa]
      pensions = described_class.new(user).format_service_branches_for_pensions(branches)
      expected_pensions = {
        'army' => true,
        'navy' => true,
        'airForce' => true,
        'coastGuard' => true,
        'marineCorps' => true,
        'spaceForce' => true,
        'usphs' => true,
        'noaa' => true
      }
      expect(pensions).to eq(expected_pensions)
    end

    it 'filters out invalid branches' do
      expect(described_class.new(user).format_service_branches_for_pensions(['army', nil])).to eq({
                                                                                                    'army' => true
                                                                                                  })
    end
  end

  describe '#first_uniformed_entry_date' do
    it 'returns the first uniformed service entry date' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, uniformed_service_initial_entry_date: '2000-18-11'
        )
      )

      expect(described_class.new(user).first_uniformed_entry_date).to eq('2000-18-11')
    end
  end

  describe '#last_active_discharge_date' do
    it 'returns the last active discharge date' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, release_from_active_duty_date: '2000-18-11'
        )
      )

      expect(described_class.new(user).last_active_discharge_date).to eq('2000-18-11')
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

    it 'properly rescues and error' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, episodes: 'This should be an Array'
        )
      )

      expect(Rails.logger).to receive(:error).with(
        'Error fetching service branches for Pension prefill: ' \
        "undefined method `branch_of_service' for an instance of String"
      )
      expect(described_class.new(nil).service_branches_for_pensions).to eq({})
    end
  end

  describe '#service_number' do
    it 'returns an object of valid branches' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, episodes: [army_episode], uniformed_service_initial_entry_date: '2000-18-11'
        )
      )

      expect(described_class.new(user).service_number).to eq('796111863')
    end

    it 'properly rescues and error' do
      military_personnel_stub = instance_double(VAProfile::MilitaryPersonnel::Service)

      allow(VAProfile::MilitaryPersonnel::Service).to receive(:new) { military_personnel_stub }
      allow(military_personnel_stub).to receive(:get_service_history).and_return(
        VAProfile::MilitaryPersonnel::ServiceHistoryResponse.new(
          200, episodes: [army_episode], uniformed_service_initial_entry_date: ['2000-18-11']
        )
      )

      expect(Rails.logger).to receive(:error).with(
        "Error fetching service number for Pension prefill: undefined method `to_i' for an instance of Array"
      )
      expect(described_class.new(nil).service_number).to be_nil
    end
  end
end
