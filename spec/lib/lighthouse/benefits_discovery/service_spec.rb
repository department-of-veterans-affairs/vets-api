# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_discovery/service'

RSpec.describe BenefitsDiscovery::Service do
  subject { BenefitsDiscovery::Service.new }

  context 'without params' do
    it 'good question; what will this do?' do
      response = subject.get_eligible_benefits
      expect(response).to eq(?)
    end
  end

  context 'with params' do
    it 'responds successfully' do
      params = {
        date_of_birth: '2000-06-15',
        discharge_status: 'HONORABLE_DISCHARGE',
        branch_of_service: 'NAVY',
        disability_rating: 60,
        service_start_date: "2018-01-01",
        service_end_date: "2022-01-01",
        purpleHeartRecipientDates: ["2017-05-15","2020-01-01"]
      }
      VCR.use_cassette('lighthouse/benefits_discovery/200_response_with_all_params') do
        response = subject.get_eligible_benefits
        expect(response).to eq(params)
      end
    end
  end

  context 'with empty values' do
    it 'removes empty params' do
      params = {
        date_of_birth: nil,
        discharge_status: nil,
        branch_of_service: nil,
        disability_rating: nil,
        service_start_date: nil,
        service_end_date: nil,
        purpleHeartRecipientDates: nil
      }
      expect(subject).to receive(:perform).with(
        :post, 'benefits-discovery-service/v0/recommendations', '{}', {"x-api-key"=>nil, "x-app-id"=>nil}
      )
      subject.get_eligible_benefits(params)
    end

    it 'responds' do
      params = {
        date_of_birth: nil,
        discharge_status: nil,
        branch_of_service: nil,
        disability_rating: nil,
        service_start_date: nil,
        service_end_date: nil,
        purpleHeartRecipientDates: nil
      }
      VCR.use_cassette('lighthouse/benefits_discovery/200_response_without_params') do
        subject.get_eligible_benefits(params)
      end
    end
  end
end
