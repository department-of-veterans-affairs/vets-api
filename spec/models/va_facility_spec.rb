# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAFacility, type: :model do
  let(:bbox) { [-73.401, 40.685, -77.36, 43.03] }
  let(:services) { nil }

  describe 'class methods' do
    context '#query' do
      it 'fetches the list of vet_center facilities designated by bbox and type' do
        VCR.use_cassette('facilities/va/ny_vetcenter') do
          type = 'vet_center'
          va_facilities = described_class.query(bbox: bbox, type: type, services: services)
          expect(va_facilities).to be_an(Array)
          expect(va_facilities).to all(be_a(VAFacility))
          # NOTE: website does not exist for vetcenter
          expect(va_facilities.first.attributes.keys).to contain_exactly(
            :access, :address, :classification, :facility_type, :feedback, :hours, :lat,
            :long, :name, :phone, :services, :unique_id
          )
          expect(va_facilities.map(&:hours))
            .to all(be_a(Hash).and(include(*Date::DAYNAMES.map(&:downcase))))
          expect(va_facilities.map(&:hours).map(&:values).flatten).to all(be)
        end
      end

      it 'fetches the list of health facilities designated by bbox and type' do
        VCR.use_cassette('facilities/va/ny_health') do
          type = 'health'
          va_facilities = described_class.query(bbox: bbox, type: type, services: services)
          expect(va_facilities).to be_an(Array)
          expect(va_facilities).to all(be_a(VAFacility))
          expect(va_facilities.first.attributes.keys).to contain_exactly(
            :access, :address, :classification, :facility_type, :feedback, :hours, :lat,
            :long, :name, :phone, :services, :unique_id, :website
          )
          expect(va_facilities.map(&:hours))
            .to all(be_a(Hash).and(include(*Date::DAYNAMES)))
          expect(va_facilities.map(&:hours).map(&:values).flatten).to all(be)
        end
      end

      it 'fetches the list of benefits facilities designated by bbox and type' do
        VCR.use_cassette('facilities/va/ny_benefits') do
          type = 'benefits'
          va_facilities = described_class.query(bbox: bbox, type: type, services: services)
          expect(va_facilities).to be_an(Array)
          expect(va_facilities).to all(be_a(VAFacility))
          expect(va_facilities.first.attributes.keys).to contain_exactly(
            :access, :address, :classification, :facility_type, :feedback, :hours, :lat,
            :long, :name, :phone, :services, :unique_id, :website
          )
          expect(va_facilities.map(&:hours))
            .to all(be_a(Hash).and(include(*Date::DAYNAMES)))
          expect(va_facilities.map(&:hours).map(&:values).flatten).to all(be)
        end
      end

      it 'fetches the list of cemetery facilities designated by bbox and type' do
        VCR.use_cassette('facilities/va/ny_cemetery') do
          type = 'cemetery'
          va_facilities = described_class.query(bbox: bbox, type: type, services: services)
          expect(va_facilities).to be_an(Array)
          expect(va_facilities).to all(be_a(VAFacility))
          expect(va_facilities.first.attributes.keys).to contain_exactly(
            :access, :address, :classification, :facility_type, :feedback, :hours, :lat,
            :long, :name, :phone, :services, :unique_id, :website
          )
          expect(va_facilities.map(&:hours))
            .to all(be_a(Hash).and(include(*Date::DAYNAMES)))
          expect(va_facilities.map(&:hours).map(&:values).flatten).to all(be)
        end
      end
    end
  end
end
