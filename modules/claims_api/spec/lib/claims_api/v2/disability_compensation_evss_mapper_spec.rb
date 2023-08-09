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
        expect(evss_data[:veteran][:currentVAEmployee]).to eq(false)
        expect(evss_data[:veteran][:emailAddress]).to eq('valid@somedomain.com')
      end
    end

    context '526 section 5, claim info: disabilities' do
      it 'maps the attributes correctly' do
        disability = evss_data[:disabilities][0]
        secondary = disability[:secondaryDisabilities][0]

        expect(disability[:disabilityActionType]).to eq('REOPEN')
        expect(disability[:name]).to eq('Traumatic Brain Injury')
        expect(disability[:classificationCode]).to eq('9020')
        expect(disability[:serviceRelevance]).to eq('ABCDEFG')
        expect(disability[:ratedDisabilityId]).to eq('ABCDEFGHIJKLMNOPQRSTUVWX')
        expect(disability[:diagnosticCode]).to eq(9020)
        expect(disability[:exposureOrEventOrInjury]).to eq('EXPOSURE')
        expect(disability[:approximateBeginDate]).to eq({ year: 2018, month: 11, day: 3 })

        expect(secondary[:name]).to eq('Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders')
        expect(secondary[:disabilityActionType]).to eq('SECONDARY')
        expect(secondary[:serviceRelevance]).to eq('ABCDEFGHIJKLMNOPQ')
        expect(secondary[:classificationCode]).to eq('9010')
        expect(secondary[:approximateBeginDate]).to eq({ year: 2018, month: 12, day: 3 })
      end
    end
  end
end
