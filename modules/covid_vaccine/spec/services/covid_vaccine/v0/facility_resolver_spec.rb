# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::FacilityResolver do
  subject { described_class.new }

  describe '#resolve' do
    describe 'submission includes facility ID' do
      it 'returns facilty ID with prefix removed' do
        sub = create(:covid_vax_expanded_registration, raw_options: { 'preferred_facility' => 'vha_648' })
        expect(subject.resolve(sub)).to eq('648')
      end
    end

    describe 'submission includes unambiguous facility name' do
      it 'returns the corresponding facility ID' do
        sub = create(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'Cheyenne VA Medical Center' })
        expect(subject.resolve(sub)).to eq('442')
      end
    end

    describe 'submission includes unmapped facility name' do
      it 'returns nil' do
        sub = create(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'Fake VA Medical Center' })
        expect(subject.resolve(sub)).to be_nil
      end
    end

    describe 'submission includes ambiguous facility name' do
      it 'returns the closest facility by zip for Fayetteville NC' do
        VCR.use_cassette('covid_vaccine/facilities/query_27330', match_requests_on: %i[path query]) do
          sub = create(:covid_vax_expanded_registration,
                       raw_options: { 'preferred_facility' => 'Fayetteville VA Medical Center', 'zip_code' => '27330' })
          expect(subject.resolve(sub)).to eq('565')
        end
      end

      it 'returns the closest facility by zip for Marion IN' do
        VCR.use_cassette('covid_vaccine/facilities/query_46953', match_requests_on: %i[path query]) do
          sub = create(:covid_vax_expanded_registration,
                       raw_options: { 'preferred_facility' => 'Marion VA Medical Center', 'zip_code' => '46953' })
          expect(subject.resolve(sub)).to eq('610')
        end
      end

      it 'returns nil if supplied zip is nowhere near candidate facilties' do
        VCR.use_cassette('covid_vaccine/facilities/query_95959', match_requests_on: %i[path query]) do
          sub = create(:covid_vax_expanded_registration,
                       raw_options: { 'preferred_facility' => 'Fayetteville VA Medical Center', 'zip_code' => '95959' })
          expect(subject.resolve(sub)).to be_nil
        end
      end

      it 'returns nil if facility lookup fails' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities)
          .and_raise(StandardError.new('facilities exception'))
        sub = create(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => 'Fayetteville VA Medical Center', 'zip_code' => '62999' })
        expect(subject.resolve(sub)).to be_nil
      end
    end

    describe 'submission has empty preferred_facility' do
      it 'resolves a facility if zip code is valid' do
        VCR.use_cassette('covid_vaccine/facilities/query_60607', match_requests_on: %i[path query]) do
          sub = create(:covid_vax_expanded_registration,
                       raw_options: { 'preferred_facility' => nil, 'zip_code' => '60607' })
          expect(subject.resolve(sub)).to eq('537')
        end
      end

      it 'returns nil if facility is invalid' do
        sub = create(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => nil, 'zip_code' => '88888' })
        expect(subject.resolve(sub)).to be_nil
      end

      it 'returns nil if facility service errors out' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        sub = create(:covid_vax_expanded_registration,
                     raw_options: { 'preferred_facility' => nil, 'zip_code' => '97214' })
        expect(subject.resolve(sub)).to be_nil
      end
    end
  end
end
