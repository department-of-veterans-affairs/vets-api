# frozen_string_literal: true

require 'rails_helper'

module FacilitiesApi
  describe V1::PPMS::Response, team: :facilities do
    let(:body) do
      FactoryBot.build_list(
        :facilities_api_v1_ppms_provider, 10, :from_provider_locator
      ).collect { |x| x.attributes.except(:id) }
    end
    let(:params) do
      {
        page: 2,
        per_page: 5
      }
    end
    let(:ppms_response) { V1::PPMS::Response.new(body, params) }

    describe '.initialize' do
      it 'takes a body argument and sets the body attribute' do
        expect(ppms_response.body).to eql(body)
      end

      it 'stores the param argument in the param attribute' do
        expect(ppms_response.params).to eql(params)
      end

      it 'parses current_page from the params' do
        expect(ppms_response.current_page).to be(2)
      end

      it 'has a default current_page of 1' do
        expect(V1::PPMS::Response.new(body).current_page).to be(1)
      end

      it 'parses the per_page from the params' do
        expect(ppms_response.per_page).to be(5)
      end

      it 'has a default per_page of 10' do
        expect(V1::PPMS::Response.new(body).per_page).to be(10)
      end

      it 'calculates offset' do
        expect(ppms_response.offset).to be(5)
      end

      it 'calculates total_entries' do
        expect(ppms_response.total_entries).to be(11)
      end
    end

    describe '#providers' do
      it 'creates Providers from a ppms response with offset' do
        ppms_response_attributes = ppms_response.providers.collect do |provider|
          provider.attributes.except(:id)
        end
        expect(ppms_response_attributes).to match(body[5, 5])
      end

      it 'sets all Providers ID to a sha256' do
        ppms_response_ids = ppms_response.providers.collect(&:id)
        expect(ppms_response_ids.collect(&:length)).to all(eql(64))
      end
    end

    describe '#places_of_service' do
      it 'creates Providers from a ppms response with offset' do
        ppms_response_attributes = ppms_response.places_of_service.collect do |provider|
          provider.attributes.except(:id)
        end
        expect(ppms_response_attributes).to match(body[5, 5])
      end

      it 'sets all Providers ID to a sha256' do
        ppms_response_ids = ppms_response.places_of_service.collect(&:id)
        expect(ppms_response_ids.collect(&:length)).to all(eql(64))
      end

      it 'sets all provider_type to GroupPracticeOrAgency' do
        ppms_response_provider_types = ppms_response.places_of_service.collect(&:provider_type)
        expect(ppms_response_provider_types).to all(eql('GroupPracticeOrAgency'))
      end
    end
  end
end
