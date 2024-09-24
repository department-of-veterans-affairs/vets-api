# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/v1/response'

RSpec.describe Lighthouse::Facilities::V1::Response, type: :model do
  subject { described_class.new(response_body, response_status) }

  let(:data) do
    [
      { 'id' => 'vha_042', 'attributes' => { 'name' => 'Facility One', 'facilityType' => 'va_health_facility' } },
      { 'id' => 'vha_043', 'attributes' => { 'name' => 'Facility Two', 'facilityType' => 'va_health_facility' } }
    ]
  end

  let(:meta) do
    {
      'pagination' => {
        'currentPage' => 1,
        'perPage' => 10,
        'totalEntries' => 20
      },
      'distances' => [
        { 'distance' => 5.0 },
        { 'distance' => 10.0 }
      ]
    }
  end

  let(:response_body) do
    body = { 'links' => {} }
    body['meta'] = meta unless meta.nil?
    body['data'] = data unless data.nil?
    body.to_json
  end

  let(:response_status) { 200 }
  let(:response) { described_class.new(response_body, response_status) }

  describe '#initialize' do
    it 'parses the response body and sets attributes' do
      expect(subject.body).to eq(response_body)
      expect(subject.status).to eq(response_status)
      expect(subject.data).to be_an(Array)
      expect(subject.meta).to be_a(Hash)
      expect(subject.current_page).to eq(1)
      expect(subject.per_page).to eq(10)
      expect(subject.total_entries).to eq(20)
    end

    context 'no data attribute' do
      let(:data) { nil }

      it 'sets data to empty array' do
        expect(subject.body).to eq(response_body)
        expect(subject.status).to eq(response_status)
        expect(subject.data).to be_an(Array)
        expect(subject.meta).to be_a(Hash)
        expect(subject.current_page).to eq(1)
        expect(subject.per_page).to eq(10)
        expect(subject.total_entries).to eq(20)
      end
    end
  end

  describe '#facilities' do
    it 'returns a paginated collection of facilities' do
      facilities = subject.facilities
      expect(facilities).to be_an_instance_of(WillPaginate::Collection)
      expect(facilities.size).to eq(2)
      expect(facilities.current_page).to eq(1)
      expect(facilities.per_page).to eq(10)
      expect(facilities.total_entries).to eq(20)

      facility = facilities.first
      expect(facility).to be_an_instance_of(Lighthouse::Facilities::Facility)
      expect(facility.distance).to eq(5.0)
    end

    it 'creates facilities with underscore attributes' do
      facility = subject.facilities.first
      expect(facility.attributes.keys).to include(:name, :facility_type)
    end

    context 'data is nil' do
      let(:data) { nil }

      it 'returns response with no facilities' do
        facilities = subject.facilities
        expect(facilities).to be_an_instance_of(WillPaginate::Collection)
        expect(facilities.size).to eq(0)
        expect(facilities.current_page).to eq(1)
        expect(facilities.per_page).to eq(10)
        expect(facilities.total_entries).to eq(20)
      end
    end
  end
end
