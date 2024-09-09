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
    let(:target_veteran) do
      OpenStruct.new(
        icn: '1013062086V794840',
        first_name: 'abraham',
        last_name: 'lincoln',
        loa: { current: 3, highest: 3 },
        ssn: '796111863',
        edipi: '8040545646',
        participant_id: '600061742',
        mpi: OpenStruct.new(
          icn: '1013062086V794840',
          profile: OpenStruct.new(ssn: '796111863')
        )
      )
    end
    let(:evss_data) do
      ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
    end

    RSpec.shared_examples 'does not map any values' do |section|
      it "does not map any of the #{section} values" do
        expect(evss_data[section]).to eq(nil)
      end
    end

    context '526 section 0' do
      it 'maps the cert correctly' do
        expect(evss_data[:claimantCertification]).to be true
      end

      context 'When claimProcessType is BDD_PROGRAM' do
        let(:claim_process_type) { 'BDD_PROGRAM' }

        it 'maps correctly to BDD_PROGRAM_CLAIM' do
          form_data['data']['attributes']['claimProcessType'] = claim_process_type
          auto_claim = create(:auto_established_claim, form_data: form_data['data']['attributes'])
          evss_data = ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
          claim_process_type = evss_data[:claimProcessType]
          expect(claim_process_type).to eq('BDD_PROGRAM_CLAIM')
        end
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
        expect(disability[:classificationCode]).to eq('9014')
        expect(disability[:serviceRelevance]).to eq('ABCDEFG')
        expect(disability[:ratedDisabilityId]).to eq('ABCDEFGHIJKLMNOPQRSTUVWX')
        expect(disability[:diagnosticCode]).to eq(9020)
        expect(disability[:exposureOrEventOrInjury]).to eq('EXPOSURE')

        expect(secondary_disability[:name]).to eq('Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders')
        expect(secondary_disability[:disabilityActionType]).to eq('SECONDARY')
        expect(secondary_disability[:serviceRelevance]).to eq('ABCDEFGHIJKLMNOPQ')
        expect(secondary_disability[:classificationCode]).to eq('9014')
      end

      it 'maps the PACT attribute correctly' do
        expect(evss_data[:disabilities][0][:specialIssues][0]).to eq('PACT')
      end

      context 'When there are special issues' do
        let(:disability) do
          {
            disabilityActionType: 'NEW',
            name: 'hypertension',
            approximateDate: nil,
            classificationCode: '',
            serviceRelevance: '',
            isRelatedToToxicExposure: false,
            exposureOrEventOrInjury: '',
            ratedDisabilityId: '',
            diagnosticCode: 0,
            secondaryDisabilities: nil,
            specialIssues: %w[POW EMP]
          }
        end

        it 'maps the special issues attributes correctly' do
          form_data['data']['attributes']['disabilities'][0] = disability
          auto_claim = create(:auto_established_claim, form_data: form_data['data']['attributes'])
          evss_data = ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
          special_issue_first = evss_data[:disabilities][0][:specialIssues][0]
          special_issue_second = evss_data[:disabilities][0][:specialIssues][1]
          expect(special_issue_first).to eq('POW')
          expect(special_issue_second).to eq('EMP')
        end
      end

      context 'When there are special issues and a PACT disability' do
        let(:disability) do
          {
            disabilityActionType: 'NEW',
            name: 'hypertension',
            approximateDate: nil,
            classificationCode: '',
            serviceRelevance: '',
            isRelatedToToxicExposure: true,
            exposureOrEventOrInjury: '',
            ratedDisabilityId: '',
            diagnosticCode: 0,
            secondaryDisabilities: nil,
            specialIssues: %w[POW EMP]
          }
        end

        it 'maps the special issues attributes correctly and appends PACT' do
          form_data['data']['attributes']['disabilities'][0] = disability
          auto_claim = create(:auto_established_claim, form_data: form_data['data']['attributes'])
          evss_data = ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
          includes_pow = evss_data[:disabilities][0][:specialIssues].include? 'POW'
          includes_emp = evss_data[:disabilities][0][:specialIssues].include? 'EMP'
          includes_pact = evss_data[:disabilities][0][:specialIssues].include? 'PACT'
          expect(includes_pow).to eq(true)
          expect(includes_emp).to eq(true)
          expect(includes_pact).to eq(true)
        end
      end

      context 'When serviceRelevance is blank' do
        let(:disability) do
          {
            disabilityActionType: 'INCREASE',
            name: 'hypertension',
            approximateDate: nil,
            classificationCode: '',
            serviceRelevance: '',
            isRelatedToToxicExposure: false,
            exposureOrEventOrInjury: '',
            ratedDisabilityId: '',
            diagnosticCode: 0,
            secondaryDisabilities: nil
          }
        end

        it 'mapping logic correctly removes attribute' do
          form_data['data']['attributes']['disabilities'][1] = disability
          auto_claim = create(:auto_established_claim, form_data: form_data['data']['attributes'])
          evss_data = ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
          disability = evss_data[:disabilities][1]
          expect(disability[:serviceRelevance]).to eq(nil)
        end
      end

      context 'When classificationcode is null' do
        let(:disability) do
          {
            disabilityActionType: 'INCREASE',
            name: 'hypertension',
            approximateDate: nil,
            classificationCode: nil,
            serviceRelevance: '',
            isRelatedToToxicExposure: false,
            exposureOrEventOrInjury: '',
            ratedDisabilityId: '',
            diagnosticCode: 0,
            secondaryDisabilities: nil
          }
        end

        it 'mapping logic correctly removes attribute' do
          form_data['data']['attributes']['disabilities'][1] = disability
          auto_claim = create(:auto_established_claim, form_data: form_data['data']['attributes'])
          evss_data = ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim).map_claim[:form526]
          disability = evss_data[:disabilities][1]
          expect(disability[:classificationCode]).to eq(nil)
        end
      end
    end

    context '526 section 6, service information: service periods' do
      it 'maps the attributes correctly' do
        service_periods = evss_data[:serviceInformation][:servicePeriods][0]

        expect(service_periods[:serviceBranch]).to eq('Public Health Service')
        expect(service_periods[:activeDutyBeginDate]).to eq('2008-11-14')
        expect(service_periods[:activeDutyEndDate]).to eq('2023-10-30')
        expect(service_periods[:serviceComponent]).to eq('Active')
        expect(service_periods[:separationLocationCode]).to eq('98282')
      end

      it 'maps the confinements attribute correctly' do
        first_confinement = evss_data[:serviceInformation][:confinements][0]
        second_confinement = evss_data[:serviceInformation][:confinements][1]

        expect(first_confinement[:confinementBeginDate]).to eq('2018-06-04')
        expect(first_confinement[:confinementEndDate]).to eq('2018-07-04')
        expect(second_confinement[:confinementBeginDate]).to eq('2020-06')
        expect(second_confinement[:confinementEndDate]).to eq('2020-07')
      end
    end

    context '526 section 7, service pay information' do
      it_behaves_like 'does not map any values', :servicePay
    end

    context '526 section 8, direct deposit information' do
      it_behaves_like 'does not map any values', :directDeposit
    end

    context '526 Overflow Text' do
      it_behaves_like 'does not map any values', :claimNotes
    end
  end
end
