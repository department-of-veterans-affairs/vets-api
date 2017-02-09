# frozen_string_literal: true
require 'rails_helper'
require 'mvi/responses/find_candidate'

describe MVI::Responses::FindCandidate do
  context 'given a valid response' do
    let(:faraday_response) { instance_double('Faraday::Response') }
    let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_response.xml')) }
    let(:find_candidate_response) { MVI::Responses::FindCandidate.new(faraday_response) }

    before(:each) do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#invalid?' do
      it 'should return false' do
        expect(find_candidate_response.invalid?).to be_falsey
      end
    end

    describe '#failure?' do
      it 'should return false' do
        expect(find_candidate_response.failure?).to be_falsey
      end
    end

    describe '.body' do
      context 'with middle name and icn, mhv correlation ids' do
        it 'should filter the patient attributes the system is interested in' do
          expect(find_candidate_response.body).to eq(
            birth_date: '19800101',
            edipi: '1234^NI^200DOD^USDOD^A',
            vba_corp_id: '12345678^PI^200CORP^USVBA^A',
            family_name: 'Smith',
            gender: 'M',
            given_names: %w(John William),
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv_ids: ['123456^PI^200MHV^USVHA^A'],
            ssn: '555443333',
            active_status: 'active',
            address: {
              streetAddressLine: '121 A St',
              city: 'Austin',
              state: 'TX',
              postalCode: '78772',
              country: 'USA'
            }
          )
        end
      end

      context 'when name parsing fails' do
        it 'should set the names to false' do
          allow(find_candidate_response).to receive(:get_patient_name).and_return(nil)
          expect(find_candidate_response.body).to eq(
            birth_date: '19800101',
            edipi: '1234^NI^200DOD^USDOD^A',
            vba_corp_id: '12345678^PI^200CORP^USVBA^A',
            family_name: nil,
            gender: 'M',
            given_names: nil,
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv_ids: ['123456^PI^200MHV^USVHA^A'],
            ssn: '555443333',
            active_status: 'active',
            address: {
              streetAddressLine: '121 A St',
              city: 'Austin',
              state: 'TX',
              postalCode: '78772',
              country: 'USA'
            }
          )
        end
      end
    end
  end

  context 'with no middle name, missing and alternate correlation ids, multiple other_ids' do
    let(:faraday_response) { instance_double('Faraday::Response') }
    let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_missing_attrs.xml')) }
    let(:find_candidate_missing_attrs) { MVI::Responses::FindCandidate.new(faraday_response) }

    describe '#body' do
      it 'should filter with only first name and retrieve correct MHV id' do
        allow(faraday_response).to receive(:body) { body }
        expect(find_candidate_missing_attrs.body).to eq(
          birth_date: '19490304',
          edipi: nil,
          mhv_ids: ['1100792239^PI^200MHS^USVHA^A'],
          vba_corp_id: '9100792239^PI^200CORP^USVBA^A',
          family_name: 'Jenkins',
          gender: 'M',
          given_names: %w(Mitchell),
          icn: '1008714701V416111^NI^200M^USVHA^P',
          ssn: '796122306',
          active_status: 'active',
          address: {
            streetAddressLine: '121 A St',
            city: 'Austin',
            state: 'TX',
            postalCode: '78772',
            country: 'USA'
          }
        )
      end
    end
  end

  context 'with no subject element' do
    let(:faraday_response) { instance_double('Faraday::Response') }
    let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_no_subject.xml')) }
    let(:find_candidate_response_mhv_id) { MVI::Responses::FindCandidate.new(faraday_response) }

    describe '#body' do
      it 'return nil if the response includes no suject element' do
        allow(faraday_response).to receive(:body) { body }
        expect(find_candidate_response_mhv_id.body).to be_nil
      end
    end
  end

  context 'given an invalid response' do
    let(:faraday_response) { instance_double('Faraday::Response') }
    let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_invalid_response.xml')) }
    let(:find_candidate_invalid_response) { MVI::Responses::FindCandidate.new(faraday_response) }

    before(:each) do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#invalid?' do
      it 'should return true' do
        expect(find_candidate_invalid_response.invalid?).to be_truthy
      end
    end

    describe '#failure?' do
      it 'should return false' do
        expect(find_candidate_invalid_response.failure?).to be_falsey
      end
    end
  end

  context 'given a failure response' do
    context 'invalid registration identification' do
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_failure_response.xml')) }
      let(:find_candidate_failure_response) { MVI::Responses::FindCandidate.new(faraday_response) }

      before(:each) do
        allow(faraday_response).to receive(:body) { body }
      end

      describe '#invalid?' do
        it 'should return false' do
          expect(find_candidate_failure_response.invalid?).to be_falsey
        end
      end

      describe '#failure?' do
        it 'should return true' do
          expect(find_candidate_failure_response.failure?).to be_truthy
        end
      end

      describe '#multiple_match?' do
        it 'should return false' do
          expect(find_candidate_failure_response.multiple_match?).to be_falsey
        end
      end
    end
    context 'multiple match' do
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_multiple_match_response.xml')) }
      let(:find_candidate_multiple_response) { MVI::Responses::FindCandidate.new(faraday_response) }

      before(:each) do
        allow(faraday_response).to receive(:body) { body }
      end

      describe '#invalid?' do
        it 'should return false' do
          expect(find_candidate_multiple_response.invalid?).to be_falsey
        end
      end

      describe '#failure?' do
        it 'should return true' do
          expect(find_candidate_multiple_response.failure?).to be_truthy
        end
      end

      describe '#multiple_match?' do
        it 'should return true' do
          expect(find_candidate_multiple_response.multiple_match?).to be_truthy
        end
      end
    end
  end

  context 'with multiple MHV IDs' do
    let(:faraday_response) { instance_double('Faraday::Response') }
    let(:body) { Ox.parse(File.read('spec/support/mvi/find_candidate_multiple_mhv_response.xml')) }
    let(:find_candidate_multiple_mhvids) { MVI::Responses::FindCandidate.new(faraday_response) }

    before(:each) do
      allow(faraday_response).to receive(:body) { body }
    end

    it 'returns an array of mhv ids' do
      expect(find_candidate_multiple_mhvids.body).to eq(
        birth_date: '19800101',
        edipi: '1122334455^NI^200DOD^USDOD^A',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A',
        family_name: 'Ranger',
        gender: 'M',
        given_names: %w(Steve A),
        icn: '12345678901234567^NI^200M^USVHA^P',
        mhv_ids: %w(12345678901^PI^200MH^USVHA^A 12345678902^PI^200MH^USVHA^A),
        ssn: '111223333',
        active_status: 'active',
        address: {
          streetAddressLine: '42 MAIN ST',
          city: 'SPRINGFIELD',
          state: 'IL',
          postalCode: '62722',
          country: 'USA'
        }
      )
    end
  end
end
