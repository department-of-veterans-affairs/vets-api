# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacilitiesQuery do
  describe '#query' do
    let(:setup_pdx) do
      %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348
         vba_348a vba_348d vba_348e vba_348h dod_001 dod_002].map { |id| create id }
    end

    it 'should find facility in the bbox' do
      create :vha_648A4
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      expect(FacilitiesQuery.new({bbox: bbox}).query.first.id).to eq('648A4')
    end

    it 'should find facility by type' do
      setup_pdx
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      expect(FacilitiesQuery.new({bbox: bbox }).query.size).to eq(10)
      expect(FacilitiesQuery.new({bbox: bbox, type: 'health'}).query.size).to eq(3)
      expect(FacilitiesQuery.new({bbox: bbox, type: 'benefits'}).query.size).to eq(5)
      expect(FacilitiesQuery.new({bbox: bbox, type: 'cemetery'}).query.size).to eq(1)
      expect(FacilitiesQuery.new({bbox: bbox, type: 'vet_center'}).query.size).to eq(1)
    end

    it 'should find health facilities by services' do
      setup_pdx
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      type = 'health'
      services = %w[EmergencyCare MentalHealthCare]
      expect(FacilitiesQuery.new({bbox: bbox, type: type, services: [services[0]] }).query.size).to eq(1)
      expect(FacilitiesQuery.new({bbox: bbox, type: type, services: services }).query.size).to eq(3)
    end

    it 'should find benefit facilities by services' do
      setup_pdx
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      type = 'benefits'
      services = %w[HomelessAssistance VocationalRehabilitationAndEmploymentAssistance]
      params1 = { bbox: bbox, type: type, services: [ services[0] ] }
      params2 = { bbox: bbox, type: type, services: services}
      expect( FacilitiesQuery.new(params1).query.size ).to eq(1)
      expect( FacilitiesQuery.new(params2).query.size ).to eq(5)
    end

    it 'should find facility by state code' do
      setup_pdx
      expect(FacilitiesQuery.new({state: 'WA'}).query.size).to eq(2)
    end

    it 'should find facility by state code and type' do
      setup_pdx
      expect(FacilitiesQuery.new({ state: 'WA', type: 'benefits' }).query.size).to eq(1)
    end

    it 'should find by services and state code' do
      setup_pdx
      state = 'OR'
      type = 'benefits'
      services = ['EducationAndCareerCounseling']

      result = FacilitiesQuery.new({ state: state, type: type, services: services }).query

      expect(result.size).to eq(3)
    end

    it 'should find facilities by zip code' do
      setup_pdx
      expect(FacilitiesQuery.new({ zip: '97204' }).query.size).to eq(4)
    end

    it 'should find facility by zip code and type' do
      setup_pdx
      expect(FacilitiesQuery.new({ zip: '97204', type: 'benefits' }).query.size).to eq(3)
    end

    it 'should find by zip code and services' do
      setup_pdx
      zip = '97204'
      type = 'benefits'
      services = ['EducationAndCareerCounseling']

      result = FacilitiesQuery.new({ zip: zip, type: type, services: services }).query

      expect(result.size).to eq(2)
    end

    it 'should throw an error when more than one distance param is given' do
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      params = {:state => "FL", :bbox => bbox }
      expect { FacilitiesQuery.new(params).query }.to raise_error(FacilitiesQuery::HighlanderError)
      expect { FacilitiesQuery.new(params).query }.to raise_error(FacilitiesQuery::HighlanderError)
      expect { FacilitiesQuery.new(params).query }.to raise_error(FacilitiesQuery::HighlanderError)
    end
  end

  describe '#query_klass' do
    it 'should error if only state is a param and other stuff' do
      bbox = ['-122.440689', '45.451913', '-122.786758', '45.64']
      params = {:state => "FL", :bbox => bbox }
      expect(FacilitiesQuery.new(params).geo_query?).to eq(false)
    end

    it 'should return a state query and do good ' do
      params = {:state => "FL" }
      expect(FacilitiesQuery.new(params).geo_query?).to eq(true)
    end
  end
end