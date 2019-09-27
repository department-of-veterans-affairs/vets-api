# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacilitiesQuery do
  describe '#query' do
    it 'should find facility in the bbox' do
      create :vha_648A4
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      expect(FacilitiesQuery.generate_query(bbox: bbox).run.first.id).to eq('648A4')
    end

    it 'should return an empty relation when more than one distance param is given' do
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      params = { state: 'FL', bbox: bbox }
      results = FacilitiesQuery.generate_query(params).run
      assert results.empty?
    end

    describe ' with pdx setup' do
      before(:each) do
        %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348
           vba_348a vba_348d vba_348e vba_348h dod_001 dod_002].map { |id| create id }
      end

      it 'should find facility by type' do
        bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
        expect(FacilitiesQuery.generate_query(bbox: bbox).run.size).to eq(10)
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: 'health').run.size).to eq(3)
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: 'benefits').run.size).to eq(5)
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: 'cemetery').run.size).to eq(1)
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: 'vet_center').run.size).to eq(1)
      end

      it 'should find health facilities by services' do
        bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
        type = 'health'
        services = %w[EmergencyCare MentalHealthCare]
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: type, services: [services[0]]).run.size).to eq(1)
        expect(FacilitiesQuery.generate_query(bbox: bbox, type: type, services: services).run.size).to eq(3)
      end

      it 'should find benefit facilities by services' do
        bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
        type = 'benefits'
        services = %w[HomelessAssistance VocationalRehabilitationAndEmploymentAssistance]
        params1 = { bbox: bbox, type: type, services: [services[0]] }
        params2 = { bbox: bbox, type: type, services: services }
        expect(FacilitiesQuery.generate_query(params1).run.size).to eq(1)
        expect(FacilitiesQuery.generate_query(params2).run.size).to eq(5)
      end

      it 'should find facility by state code, regardless of case' do
        expect(FacilitiesQuery.generate_query(state: 'WA').run.size).to eq(2)
        expect(FacilitiesQuery.generate_query(state: 'wa').run.size).to eq(2)
      end

      it 'should find facility by state code and type' do
        expect(FacilitiesQuery.generate_query(state: 'WA', type: 'benefits').run.size).to eq(1)
      end

      it 'should find by services and state code' do
        state = 'OR'
        type = 'benefits'
        services = ['EducationAndCareerCounseling']

        result = FacilitiesQuery.generate_query(state: state, type: type, services: services).run

        expect(result.size).to eq(3)
      end

      it 'should find facilities by zip code' do
        expect(FacilitiesQuery.generate_query(zip: '97204').run.size).to eq(4)
      end

      it 'should find facility by zip code and type' do
        expect(FacilitiesQuery.generate_query(zip: '97204', type: 'benefits').run.size).to eq(3)
      end

      it 'should find by zip code and services' do
        zip = '97204'
        type = 'benefits'
        services = ['EducationAndCareerCounseling']

        result = FacilitiesQuery.generate_query(zip: zip, type: type, services: services).run

        expect(result.size).to eq(2)
      end
    end
  end

  describe '#generate_query' do
    it 'should return IdsQuery if only ids are passed' do
      params = { ids: [1, 2, 3] }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::IdsQuery)
    end

    it 'should prioritize location and return StateQuery if ids and location are passed' do
      params = { ids: [1, 2, 3], state: 'FL' }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::StateQuery)
    end

    it 'should return base class if redundant location params are passed' do
      params = { state: 'FL', bbox: ['-122.440689', '45.451913', '-122.786758', '45.64'] }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::Base)
    end

    it 'should return base class if only one of :lat or :long are passed' do
      expect(FacilitiesQuery.generate_query(lat: '-122.440689').class).to eq(FacilitiesQuery::Base)
      expect(FacilitiesQuery.generate_query(long: '45.451913').class).to eq(FacilitiesQuery::Base)
    end

    it 'should return base class if no location params or other relevant params are passed' do
      params = { foo: 'bar' }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::Base)
    end

    it 'should return RadialQuery if both :lat and :long are passed' do
      params = { lat: '-122.440689', long: '45.451913' }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::RadialQuery)
    end

    it 'should return StateQuery if :state is passed' do
      params = { state: 'FL' }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::StateQuery)
    end

    it 'should return ZipQuery if :zip is passed' do
      params = { zip: '32708' }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::ZipQuery)
    end

    it 'should return BoundingBoxQuery if :bbox is passed' do
      params = { bbox: ['-122.440689', '45.451913', '-122.786758', '45.64'] }
      expect(FacilitiesQuery.generate_query(params).class).to eq(FacilitiesQuery::BoundingBoxQuery)
    end
  end
end
