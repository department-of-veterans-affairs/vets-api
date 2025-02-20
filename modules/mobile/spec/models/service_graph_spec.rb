# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::ServiceGraph, type: :model do
  subject do
    Mobile::V0::ServiceGraph.new(
      %i[bgs evss],
      %i[iam_ssoe auth],
      %i[mpi auth],
      %i[mpi evss],
      %i[arcgis facility_locator],
      %i[auth auth_dslogon],
      %i[auth auth_idme],
      %i[auth auth_mhv],
      %i[caseflow appeals],
      %i[dslogon auth_dslogon],
      %i[vet360 military_service_history],
      %i[evss claims],
      %i[evss direct_deposit_benefits],
      %i[evss letters_and_documents],
      %i[idme auth_idme],
      %i[mhv auth_mhv],
      %i[mhv secure_messaging],
      %i[vaos appointments],
      %i[vet360 user_profile_update],
      %i[eoas preneed_burial]
    )
  end

  describe '#initialize' do
    it 'has registers services as Mobile::ServiceNode instances' do
      expect(subject.services[:bgs]).to be_a(Mobile::V0::ServiceNode)
    end

    it 'adds multiple service nodes to the list' do
      expect(subject.services.size).to eq(26)
    end
  end

  describe '#affected_services' do
    context 'with one window' do
      let(:mobile_maintenance_evss) { build(:mobile_maintenance_evss_first) }
      let(:affected_services) { subject.affected_services([mobile_maintenance_evss]) }

      it 'finds the api services (leaves) that are downstream from the queried node' do
        expect(affected_services.keys).to eq(%i[claims direct_deposit_benefits letters_and_documents])
      end

      it 'does not include upstream services in the list' do
        expect(affected_services.keys).not_to include(%i[bgs evss])
      end

      it 'includes downstream windows with the upstream start time' do
        expect(affected_services[:claims].start_time).to eq(mobile_maintenance_evss.start_time)
      end

      it 'includes downstream windows with the upstream end time' do
        expect(affected_services[:claims].end_time).to eq(mobile_maintenance_evss.end_time)
      end
    end

    context 'with two overlapping windows' do
      let(:maintenance_bgs) { build(:mobile_maintenance_bgs_first) }
      let(:maintenance_mpi) { build(:mobile_maintenance_mpi) }
      let(:affected_services) { subject.affected_services([maintenance_bgs, maintenance_mpi]) }

      it 'finds the api services (leaves) that are downstream from the queried node' do
        expect(affected_services.keys).to eq(%i[claims direct_deposit_benefits letters_and_documents auth_dslogon
                                                auth_idme auth_mhv])
      end

      it 'does not include upstream services in the list' do
        expect(affected_services.keys).not_to include(%i[bgs evss])
      end

      it 'includes downstream windows with the earliest upstream start time' do
        expect(affected_services[:claims].start_time).to eq(maintenance_bgs.start_time)
      end

      it 'includes downstream windows with the latest upstream end time' do
        expect(affected_services[:claims].end_time).to eq(maintenance_mpi.end_time)
      end
    end
  end
end
