# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V1::PPMS::Response, team: :facilities do
  let(:response) { double('response', status: 200, body: { 'value' => body }) }

  let(:body) do
    FactoryBot.build_list(
      :facilities_api_v1_ppms_provider, 10, :from_provider_locator
    ).collect do |x|
      x.attributes.except(:id)
    end
  end

  let(:params) do
    {
      page: 2,
      per_page: 5
    }
  end

  let(:ppms_response) { FacilitiesApi::V1::PPMS::Response.new(response, params) }

  describe '.initialize' do
    it 'takes a body argument and sets the body attribute' do
      expect(ppms_response.body).to eql(body)
    end

    it 'parses current_page from the params' do
      expect(ppms_response.current_page).to be(2)
    end

    it 'has a default current_page of 1' do
      expect(FacilitiesApi::V1::PPMS::Response.new(response).current_page).to be(1)
    end

    it 'parses the per_page from the params' do
      expect(ppms_response.per_page).to be(5)
    end

    it 'has a default per_page of 10' do
      expect(FacilitiesApi::V1::PPMS::Response.new(response).per_page).to be(10)
    end

    it 'calculates total_entries' do
      expect(ppms_response.total_entries).to be(10)
    end
  end

  describe '#providers' do
    it 'creates Providers from a ppms response with offset' do
      ppms_response_attributes = ppms_response.providers.collect do |provider|
        provider.attributes.except(:id)
      end
      expect(ppms_response_attributes).to match(body)
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
      expect(ppms_response_attributes).to match(body)
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
