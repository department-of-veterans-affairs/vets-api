# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobileFacilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:cassette_options) { { match_requests_on: %i[method path query] } }

  before do
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#get_scheduling_configurations' do
    context 'using CSCS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                  instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                  instance_of(User)).and_return(false)
      end

      context 'with a single facility id arg' do
        let(:facility_id) { '489' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                           cassette_options) do
            @response = subject.get_scheduling_configurations(facility_id)
          end
        end

        it 'returns a scheduling configuration with the correct id' do
          expect(@response.dig(:data, 0, :facility_id)).to eq(facility_id)
        end
      end

      context 'with multiple facility ids arg' do
        let(:facility_ids) { '489,984' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_200',
                           cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids)
          end
        end

        it 'returns scheduling configurations with the correct ids' do
          expect(@response.dig(:data, 0, :facility_id)).to eq('489')
          expect(@response.dig(:data, 1, :facility_id)).to eq('984')
        end
      end

      context 'with multiple facility ids and cc enabled args' do
        let(:facility_ids) { '489,984' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cc_cscs_200',
                           cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids, true)
          end
        end

        it 'returns scheduling configuration with the correct id' do
          expect(@response.dig(:data, 0, :facility_id)).to eq('984')
        end
      end

      context 'when the upstream server returns a 500' do
        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cscs_500',
                           cassette_options) do
            expect { subject.get_scheduling_configurations(489, false) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end

    context 'using MFS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                  instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                  instance_of(User)).and_return(false)
      end

      context 'with a single facility id arg' do
        let(:facility_id) { '489' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200', cassette_options) do
            @response = subject.get_scheduling_configurations(facility_id)
          end
        end

        it 'returns a scheduling configuration with the correct id' do
          expect(@response.dig(:data, 0, :facility_id)).to eq(facility_id)
        end
      end

      context 'with multiple facility ids arg' do
        let(:facility_ids) { '489,984' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_200', cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids)
          end
        end

        it 'returns scheduling configurations with the correct ids' do
          expect(@response.dig(:data, 0, :facility_id)).to eq('489')
          expect(@response.dig(:data, 1, :facility_id)).to eq('984')
        end
      end

      context 'with multiple facility ids and cc enabled args' do
        let(:facility_ids) { '489,984' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_cc_mfs_200',
                           cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids, true)
          end
        end

        it 'returns scheduling configuration with the correct id' do
          expect(@response.dig(:data, 0, :facility_id)).to eq('984')
        end
      end

      context 'when the upstream server returns a 500' do
        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_mfs_500', cassette_options) do
            expect { subject.get_scheduling_configurations(489, false) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                  instance_of(User)).and_return(false)
      end

      context 'with a single facility id arg' do
        let(:facility_id) { '653' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200', cassette_options) do
            @response = subject.get_scheduling_configurations(facility_id)
          end
        end

        it 'returns a scheduling configuration with the correct id' do
          expect(@response.dig(:data, 0, :facility_id)).to eq(facility_id)
        end
      end

      context 'with multiple facility ids arg' do
        let(:facility_ids) { '653,687' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200', cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids)
          end
        end

        it 'returns scheduling configurations with the correct ids' do
          expect(@response[:data].any? { |config| config[:facility_id] == '653' }).to be(true)
          expect(@response[:data].any? { |config| config[:facility_id] == '687' }).to be(true)
        end
      end

      context 'with multiple facility ids and cc enabled args' do
        let(:facility_ids) { '523,534' }

        before do
          VCR.use_cassette('vaos/v2/mobile_facility_service/get_scheduling_configurations_vpg_200',
                           cassette_options) do
            @response = subject.get_scheduling_configurations(facility_ids, true)
          end
        end

        it 'returns scheduling configuration with the correct id' do
          expect(@response[:data].any? { |config| config[:facility_id] == '523' }).to be(true)
          expect(@response[:data].any? { |config| config[:facility_id] == '534' }).to be(true)
        end
      end
    end
  end

  describe '#get_facilities' do
    let(:facility_id) { '688' }
    let(:facility_ids) { '983, 983GB, 983GC, 983GD' }

    context 'with a facility id' do
      before do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_single_id_200', cassette_options) do
          @response = subject.get_facilities(ids: facility_id, schedulable: true)
        end
      end

      it 'returns a configuration with the correct id' do
        expect(@response.dig(:data, 0, :id)).to eq(facility_id)
      end
    end

    context 'with facility ids and schedulable not passed' do
      it 'raises ArgumentError' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200_schedulable_not_passed',
                         cassette_options) do
          expect { subject.get_facilities(ids: facility_ids) }.to raise_error(ArgumentError)
        end
      end
    end

    context 'with facility ids and schedulable false' do
      it 'filters out schedulable configurations' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200_schedulable_false_required',
                         cassette_options) do
          response = subject.get_facilities(ids: facility_ids, schedulable: false)
          expect(response[:data].size).to eq(0)
        end
      end
    end

    context 'with facility ids and schedulable true' do
      it 'returns schedulable configurations' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200_schedulable_true_required',
                         cassette_options) do
          response = subject.get_facilities(ids: facility_ids, schedulable: true)
          expect(response[:data][0][:classification]).to eq('Primary Care CBOC')
          expect(response[:data][1][:classification]).to eq('Multi-Specialty CBOC')
          expect(response[:data][2][:classification]).to eq('Other Outpatient Services (OOS)')
          expect(response[:data][3][:classification]).to eq('VA Medical Center (VAMC)')
        end
      end
    end

    context 'with multiple facility ids' do
      before do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_200', cassette_options) do
          @response = subject.get_facilities(ids: '983,984', schedulable: true)
        end
      end

      it 'returns a configuration with the correct id' do
        expect(@response.dig(:data, 0, :id)).to eq('983')
        expect(@response.dig(:data, 1, :id)).to eq('984')
      end
    end

    context 'with a facility id and children true and schedulable true' do
      before do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_schedulable_200',
                         cassette_options) do
          @response = subject.get_facilities(children: true, schedulable: true, ids: '688')
        end
      end

      it 'returns facility information for each ids' do
        expect(@response.dig(:data, 0, :id)).to eq('688')
        expect(@response.dig(:data, 1, :id)).to eq('688QA')
        expect(@response.dig(:data, 2, :id)).to eq('688GD')
        expect(@response.dig(:data, 3, :id)).to eq('688GB')
        expect(@response.dig(:data, 4, :id)).to eq('688GA')
        expect(@response.dig(:data, 5, :id)).to eq('688GG')
        expect(@response.dig(:data, 6, :id)).to eq('688GF')
        expect(@response.dig(:data, 7, :id)).to eq('688GE')
      end
    end

    context 'with a facility id and children true and schedulable false' do
      it 'filters out non schedulable facilities' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_with_children_schedulable_false_200',
                         cassette_options) do
          response = subject.get_facilities(children: true, schedulable: false, ids: '688')
          expect(response[:data].size).to eq(0)
        end
      end
    end

    context 'with multiple facility ids and children true and schedulable true' do
      before do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_multi_facilities_with_children_schedulable_true_200',
                         cassette_options) do
          @response = subject.get_facilities(children: true, schedulable: true, ids: '983, 984')
        end
      end

      it 'returns facility information for each ids' do
        expect(@response.dig(:data, 0, :id)).to eq('983')
        expect(@response.dig(:data, 1, :id)).to eq('984')
        expect(@response.dig(:data, 2, :id)).to eq('983QE')
        expect(@response.dig(:data, 3, :id)).to eq('983QA')
        expect(@response.dig(:data, 4, :id)).to eq('983QD')
        expect(@response.dig(:data, 5, :id)).to eq('983GD')
        expect(@response.dig(:data, 6, :id)).to eq('983GC')
        expect(@response.dig(:data, 7, :id)).to eq('983GB')
        expect(@response.dig(:data, 8, :id)).to eq('984GF')
        expect(@response.dig(:data, 9, :id)).to eq('984GC')
        expect(@response.dig(:data, 10, :id)).to eq('984GB')
        expect(@response.dig(:data, 11, :id)).to eq('984GD')
        expect(@response.dig(:data, 12, :id)).to eq('984GA')
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_400', cassette_options) do
          expect { subject.get_facilities(ids: 688) }.to raise_error(ArgumentError)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_500', cassette_options) do
          expect { subject.get_facilities(ids: '688', schedulable: true) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facilities_with_cache' do
    context 'with multiple facility ids, none in cache' do
      it 'returns all facility information and caches it' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_none_cached_200', cassette_options) do
          response = subject.get_facilities_with_cache('541QB', '541QA', '541QE', '541QC')
          facilities = response[:data]
          expect(facilities.size).to eq(4)
          expect(Rails.cache.exist?('vaos_facility_541QB')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QA')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QE')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QC')).to be(true)
        end
      end
    end

    context 'with multiple facility ids, some in cache' do
      it 'returns the facility information and caches uncached' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facilities_some_cached_200', cassette_options) do
          mock_541_qb = OpenStruct.new(id: '541QB', name: 'Ceveland VA Clinic')
          mock_541_qa = OpenStruct.new(id: '541QA', name: 'Summit County VA Clinic')
          Rails.cache.write('vaos_facility_541QB', mock_541_qb)
          Rails.cache.write('vaos_facility_541QA', mock_541_qa)

          response = subject.get_facilities_with_cache(%w[541QB 541QA 541QE 541QC])
          facilities = response[:data]
          expect(facilities.size).to eq(4)
          expect(Rails.cache.exist?('vaos_facility_541QB')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QA')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QE')).to be(true)
          expect(Rails.cache.exist?('vaos_facility_541QC')).to be(true)
        end
      end
    end

    context 'with multiple facility ids, all in cache' do
      it 'returns the cached facility information' do
        mock_541_qb = OpenStruct.new(id: '541QB', name: 'Ceveland VA Clinic')
        mock_541_qa = OpenStruct.new(id: '541QA', name: 'Summit County VA Clinic')
        mock_541_qe = OpenStruct.new(id: '541QE', name: 'Summit County 1 VA Clinic')
        mock_541_qc = OpenStruct.new(id: '541QC', name: 'Cleveland 1 VA Clinic')
        Rails.cache.write('vaos_facility_541QB', mock_541_qb)
        Rails.cache.write('vaos_facility_541QA', mock_541_qa)
        Rails.cache.write('vaos_facility_541QE', mock_541_qe)
        Rails.cache.write('vaos_facility_541QC', mock_541_qc)

        response = subject.get_facilities_with_cache(%w[541QB 541QA 541QE 541QC])
        facilities = response[:data]
        expect(facilities.size).to eq(4)
      end
    end
  end

  describe '#get_clinic!' do
    context 'with a valid request and station is a parent VHA facility' do
      it 'returns the clinic information' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          clinic = subject.get_clinic!(station_id: '983', clinic_id: '455')
          expect(clinic[:station_id]).to eq('983')
          expect(clinic[:id]).to eq('455')
        end
      end
    end

    context 'with a valid request and station is not a parent VHA facility' do
      it 'returns the clinic information' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          clinic = subject.get_clinic!(station_id: '983GB', clinic_id: '1053')
          expect(clinic[:station_id]).to eq('983GB')
          expect(clinic[:id]).to eq('1053')
        end
      end
    end

    context 'with a non existing clinic' do
      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_500', cassette_options) do
          expect { subject.get_clinic!(station_id: '983', clinic_id: 'does_not_exist') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_clinic_with_cache' do
    context 'with a valid request and clinic is not in the cache' do
      it 'returns the clinic information and stores it in the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to be(false)
          clinic = subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(clinic[:station_id]).to eq('983')
          expect(clinic[:id]).to eq('455')
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to be(true)
        end
      end

      it "calls '#get_clinic!' retrieving information from VAOS Service" do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          expect_any_instance_of(described_class).to receive(:get_clinic!).once.and_call_original
          subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to be(true)
        end
      end
    end

    context 'with a valid request and the clinic is in the cache' do
      it 'returns the clinic information from the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          # prime the cache
          response = subject.get_clinic!(station_id: '983', clinic_id: '455')
          Rails.cache.write('vaos_clinic_983_455', response)

          # rubocop:disable RSpec/SubjectStub
          expect(subject).not_to receive(:get_clinic!)
          # rubocop:enable RSpec/SubjectStub
          cached_response = subject.get_clinic_with_cache(station_id: '983', clinic_id: '455')
          expect(response).to eq(cached_response)
          expect(Rails.cache.exist?('vaos_clinic_983_455')).to be(true)
        end
      end
    end

    context 'with a backend server error' do
      it 'raises a BackendServiceException and nothing is cached' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_500', cassette_options) do
          expect { subject.get_clinic_with_cache(station_id: '983', clinic_id: 'does_not_exist') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.cache.exist?('vaos_clinic_983_does_not_exist')).to be(false)
        end
      end
    end
  end

  describe 'get_clinic' do
    it 'returns facility' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
        response = subject.get_clinic('983', '455')
        expect(response[:id]).to eq('455')
      end
    end

    it 'memoizes and returns nil on error' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_500', cassette_options) do
        expect_any_instance_of(described_class).to receive(:get_clinic_with_cache).and_call_original
        response = subject.get_clinic('983', 'does_not_exist')
        expect(response).to be_nil
      end
      expect_any_instance_of(described_class).not_to receive(:get_clinic_with_cache)
      response = subject.get_clinic('983', 'does_not_exist')
      expect(response).to be_nil
    end
  end

  describe '#get_clinics' do
    context 'when no station_id is passed in' do
      it 'raises ParameterMissing exception' do
        expect { subject.get_clinics(nil, 455) }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when no clinic_ids are passed in' do
      it 'raises ParameterMissing exception' do
        expect { subject.get_clinics(983, nil) }.to raise_error(Common::Exceptions::ParameterMissing)
        expect { subject.get_clinics(983, []) }.to raise_error(Common::Exceptions::ParameterMissing)
        expect { subject.get_clinics(983) }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'with a station id and single clinic id' do
      it 'returns the clinic information as the only item in an array' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinic_200', cassette_options) do
          clinic = subject.get_clinics('983', '455')
          expect(clinic.length).to eq(1)
          expect(clinic[0][:station_id]).to eq('983')
          expect(clinic[0][:id]).to eq('455')
        end
      end
    end

    context 'with a station id and multiple clinic ids as an array' do
      it 'returns an array with the information of all the clinics' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinics_200', cassette_options) do
          clinics = subject.get_clinics('983', %w[455 16])
          expect(clinics.length).to eq(2)
          expect(clinics[0][:id]).to eq('16')
          expect(clinics[1][:id]).to eq('455')
        end
      end
    end

    context 'with a station id and multiple clinic ids as individual arguments' do
      it 'returns an array with the information of all the clinics' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_clinics_200', cassette_options) do
          clinic = subject.get_clinics('983', '455', '16')
          expect(clinic.size).to eq(2)
          expect(clinic[0][:id]).to eq('16')
          expect(clinic[1][:id]).to eq('455')
        end
      end
    end
  end

  describe '#get_clinic' do
    context 'when clinic service throws an error' do
      it 'returns nil' do
        allow_any_instance_of(described_class).to receive(:get_clinic_with_cache)
          .and_raise(Common::Exceptions::BackendServiceException.new('VAOS_502', {}))

        expect(subject.get_clinic('123', '3456')).to be_nil
      end
    end
  end

  describe '#get_facility!' do
    context 'with a valid request' do
      it 'returns a facility' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200', cassette_options) do
          response = subject.get_facility!('983')
          expect(response[:id]).to eq('983')
          expect(response[:type]).to eq('va_facilities')
          expect(response[:name]).to eq('Cheyenne VA Medical Center')
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_400', cassette_options) do
          expect { subject.get_facility!('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500', cassette_options) do
          expect { subject.get_facility!('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_facility_with_cache' do
    context 'with a valid request and facility is not in the cache' do
      it 'retrieves the facility from MFS and stores the facility in the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200', cassette_options) do
          expect(Rails.cache.exist?('vaos_facility_983')).to be(false)

          response = subject.get_facility_with_cache('983')

          expect(response[:id]).to eq('983')
          expect(response[:type]).to eq('va_facilities')
          expect(response[:name]).to eq('Cheyenne VA Medical Center')
          expect(Rails.cache.exist?('vaos_facility_983')).to be(true)
        end
      end
    end

    it 'calls #get_facility!' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200', cassette_options) do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:get_facility!).once.and_call_original
        # rubocop:enable RSpec/SubjectStub
        subject.get_facility_with_cache('983')
      end
    end

    context 'with a valid request and facility is in the cache' do
      it 'returns the facility from the cache' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200', cassette_options) do
          # prime the cache
          response = subject.get_facility!('983')
          Rails.cache.write('vaos_facility_983', response)

          # rubocop:disable RSpec/SubjectStub
          expect(subject).not_to receive(:get_facility!)
          # rubocop:enable RSpec/SubjectStub
          cached_response = subject.get_facility_with_cache('983')
          expect(response).to eq(cached_response)
          expect(Rails.cache.exist?('vaos_facility_983')).to be(true)
        end
      end
    end

    context 'with a backend server error' do
      it 'raises a backend exception and nothing is cached' do
        VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500', cassette_options) do
          expect { subject.get_facility_with_cache('983') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
          expect(Rails.cache.exist?('vaos_facility_983')).to be(false)
        end
      end
    end
  end

  describe 'get_facility' do
    it 'returns facility' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200', cassette_options) do
        response = subject.get_facility('983')
        expect(response[:id]).to eq('983')
      end
    end

    it 'memoizes and returns nil on error' do
      VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_500', cassette_options) do
        expect_any_instance_of(described_class).to receive(:get_facility_with_cache).and_call_original
        response = subject.get_facility('983')
        expect(response).to be_nil
      end
      expect_any_instance_of(described_class).not_to receive(:get_facility_with_cache)
      response = subject.get_facility('983')
      expect(response).to be_nil
    end
  end

  describe '#page_params' do
    context 'when per_page is positive' do
      context 'when per_page is positive' do
        let(:pagination_params) do
          { per_page: 3, page: 2 }
        end

        it 'returns pageSize and page' do
          result = subject.send(:page_params, pagination_params)

          expect(result).to eq({ pageSize: 3, page: 2 })
        end
      end
    end

    context 'when per_page is not positive' do
      let(:pagination_params) do
        { per_page: 0, page: 2 }
      end

      it 'returns pageSize only' do
        result = subject.send(:page_params, pagination_params)

        expect(result).to eq({ pageSize: 0 })
      end
    end

    context 'when per_page does not exist' do
      let(:pagination_params) do
        { page: 2 }
      end

      it 'returns pageSize as 0' do
        result = subject.send(:page_params, pagination_params)

        expect(result).to eq({ pageSize: 0 })
      end
    end
  end
end
