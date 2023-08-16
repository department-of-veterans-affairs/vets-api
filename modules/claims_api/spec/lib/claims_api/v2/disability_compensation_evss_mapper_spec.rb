# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_evss_mapper'

describe ClaimsApi::V2::DisabilityCompensationEvssMapper do
  describe '526 claim maps to the evss container' do
    let(:form_data) do
      JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'v2',
          'veterans',
          'disability_compensation',
          'form_526_json_api.json'
        ).read
      )
    end
    let(:auto_claim) do
      create(:auto_established_claim, form_data: form_data['data']['attributes'])
    end

    let(:evss_data) { ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526] }

    RSpec.shared_examples 'does not map any values' do |section|
      it "does not map any of the #{section} values" do
        expect(evss_data[section]).to eq(nil)
      end
    end

    context '526 section 0' do
      it 'maps the cert correctly' do
        expect(evss_data[:claimantCertification]).to be true
      end
    end

    context '526 section 1' do
      it 'maps the mailing address' do
        addr = evss_data[:veteran][:currentMailingAddress]
        expect(addr[:addressLine1]).to eq('1234 Couch Street')
        expect(addr[:city]).to eq('Portland')
        expect(addr[:country]).to eq('USA')
        expect(addr[:zipFirstFive]).to eq('41726')
        expect(addr[:state]).to eq('OR')
      end

      it 'maps the other veteran info' do
        expect(evss_data[:veteran][:fileNumber]).to eq('AB123CDEF')
        expect(evss_data[:veteran][:currentlyVAEmployee]).to eq(false)
        expect(evss_data[:veteran][:emailAddress]).to eq('valid@somedomain.com')
      end
    end

    context '526 section 2, change of address' do
      it_behaves_like 'does not map any values', :changeOfAddress
    end

    context '526 section 3, homeless information' do
      it_behaves_like 'does not map any values', :homeless
    end

    context '526 section 4, exposure information' do
      it_behaves_like 'does not map any values', :toxicExposure
    end

    context '526 section 5, claim info: disabilities' do
      let(:disability) { evss_data[:disabilities][0] }
      let(:secondary_disability) { disability[:secondaryDisabilities][0] }

      it 'maps the attributes correctly' do
        expect(disability[:disabilityActionType]).to eq('NEW')
        expect(disability[:name]).to eq('Traumatic Brain Injury')
        expect(disability[:classificationCode]).to eq('9020')
        expect(disability[:serviceRelevance]).to eq('ABCDEFG')
        expect(disability[:ratedDisabilityId]).to eq('ABCDEFGHIJKLMNOPQRSTUVWX')
        expect(disability[:diagnosticCode]).to eq(9020)
        expect(disability[:exposureOrEventOrInjury]).to eq('EXPOSURE')

        expect(secondary_disability[:name]).to eq('Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders')
        expect(secondary_disability[:disabilityActionType]).to eq('SECONDARY')
        expect(secondary_disability[:serviceRelevance]).to eq('ABCDEFGHIJKLMNOPQ')
        expect(secondary_disability[:classificationCode]).to eq('9010')
      end
    end

    context '526 section 6, service information: service periods' do
      it 'maps the attributes correctly' do
        service_periods = evss_data[:serviceInformation][:servicePeriods][0]

        expect(service_periods[:serviceBranch]).to eq('Public Health Service')
        expect(service_periods[:activeDutyBeginDate]).to eq('1980-11-14')
        expect(service_periods[:activeDutyEndDate]).to eq('1991-11-30')
        expect(service_periods[:serviceComponent]).to eq('Active')
        expect(service_periods[:separationLocationCode]).to eq('ABCDEFGHIJKLMN')
      end
    end

    context '526 section 7, service pay information' do
      it_behaves_like 'does not map any values', :servicePay
    end

    context '526 section 8, direct deposit information' do
      it_behaves_like 'does not map any values', :directDeposit
    end
  end
end
