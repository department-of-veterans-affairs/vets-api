# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form526_to_lighthouse_transform'

RSpec.describe EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform do
  let(:transformer) { EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new }

  describe '#transform' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets claimant_certification to true in the Lighthouse request body' do
      lh_request_body = transformer.transform(data)
      expect(lh_request_body.claimant_certification).to be(true)
    end

    context 'when claim_date is provided' do
      let(:claim_date) { Date.new(2023, 7, 19) }

      it 'sets claim_date in the Lighthouse request body' do
        data['form526']['claimDate'] = claim_date
        lh_request_body = transformer.transform(data)
        expect(lh_request_body.claim_date).to eq(claim_date)
      end
    end

    it 'verify the LH request body is being populated correctly by default' do
      expect(transformer).to receive(:evss_claims_process_type)
        .with(data['form526'])
        .and_return('STANDARD_CLAIM_PROCESS')
      result = transformer.transform(data)

      expect(result.claim_date).to eq(nil)
      expect(result.claimant_certification).to eq(true)
      expect(result.claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
      expect(result.veteran_identification.class).to eq(Requests::VeteranIdentification)
      expect(result.change_of_address.class).to eq(Requests::ChangeOfAddress)
      expect(result.homeless.class).to eq(Requests::Homeless)
      expect(result.service_information.class).to eq(Requests::ServiceInformation)
      expect(result.disabilities.first.class).to eq(Requests::Disability)
      expect(result.direct_deposit.class).to eq(Requests::DirectDeposit)
      expect(result.treatments.first.class).to eq(Requests::Treatment)
    end
  end

  describe 'optional request objects are correctly rendered' do
    let(:submission) { create(:form526_submission, :only_526_required) }
    let(:data) { submission.form['form526'] }

    it 'renders JSON correctly when missing optional sections' do
      result = transformer.transform(data)
      expect(result.change_of_address).to be_nil
      expect(result.homeless).to be_nil
      expect(result.direct_deposit).to be_nil
      expect(result.treatments).to eq([])
    end
  end

  describe '#evss_claims_process_type' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'returns "FDC_PROGRAM" by default' do
      data['form526']['bddQualified'] = false
      data['form526']['standardClaim'] = false
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('FDC_PROGRAM')
    end

    it 'sets claimsProcessType to STANDARD_CLAIM_PROCESS in the Lighthouse request body' do
      data['form526']['bddQualified'] = false
      data['form526']['standardClaim'] = true
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('STANDARD_CLAIM_PROCESS')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body' do
      data['form526']['bddQualified'] = true
      data['form526']['standardClaim'] = false
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body, even if standardClaim is also true' do
      data['form526']['bddQualified'] = true
      data['form526']['standardClaim'] = true
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end
  end

  describe 'transform veteran identification' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets veteran identification correctly' do
      result = transformer.transform_veteran(data['form526']['veteran'])
      expect(result.currently_va_employee).to eq(false)
      expect(result.email_address).not_to be_nil
      expect(result.veteran_number).not_to be_nil
      expect(result.mailing_address).not_to be_nil
    end
  end

  describe 'transform change of address' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets change of address correctly' do
      result = transformer.transform_change_of_address(data['form526']['veteran'])
      expect(result.city).to eq('Portland')
      expect(result.dates).not_to be_nil
    end
  end

  describe 'transform homeless' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets change of address correctly' do
      result = transformer.transform_homeless(data['form526']['veteran'])
      expect(result.point_of_contact).to eq('Jane Doe')
      expect(result.currently_homeless).not_to be_nil
      expect(result.risk_of_becoming_homeless).not_to be_nil
      expect(result.point_of_contact_number).not_to be_nil
    end
  end

  describe 'transform service information' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['serviceInformation'] }

    it 'sets service information correctly' do
      result = transformer.transform_service_information(data)
      expect(result.service_periods).not_to be_nil
      expect(result.confinements).not_to be_nil
      expect(result.alternate_names).not_to be_nil
      expect(result.reserves_national_guard_service).not_to be_nil
      expect(result.service_periods.first.separation_location_code).to eq('OU812')
      expect(result.reserves_national_guard_service.component).to eq('Reserves')
    end

    it 'converts service branch to service component correctly' do
      result = transformer.send(:convert_to_service_component, 'Air Force Reserves')
      expect(result).to eq('Reserves')
      result = transformer.send(:convert_to_service_component, 'Army National Guard')
      expect(result).to eq('National Guard')
      result = transformer.send(:convert_to_service_component, 'Space Force')
      expect(result).to eq('Active')
    end
  end

  describe 'transform disabilities' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['disabilities'] }

    it 'sets disabilities correctly' do
      result = transformer.send(:transform_disabilities, data)
      expect(result.length).to eq(1)
    end

    it 'converts approximate dates' do
      result = transformer.send(:convert_approximate_date,
                                JSON.parse({ month: '03', day: '22', year: '1973' }.to_json))
      expect(result).to eq('03-22-1973')
      result = transformer.send(:convert_approximate_date, JSON.parse({ month: '03', year: '1973' }.to_json))
      expect(result).to eq('03-1973')
    end
  end

  describe 'transform direct deposit' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['directDeposit'] }

    it 'sets direct deposit correctly' do
      result = transformer.send(:transform_direct_deposit, data)
      expect(result.financial_institution_name).to eq('SomeBank')
      expect(result.account_type).to eq('CHECKING')
      expect(result.account_number).to eq('123123123123')
      expect(result.routing_number).to eq('123123123')
    end
  end

  describe 'transform treatments' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['treatments'] }

    it 'sets treatments correctly' do
      result = transformer.send(:transform_treatments, data)
      expect(result.length).to eq(2)
      expect(result.first.class).to eq(Requests::Treatment)
      expect(result.first.treated_disability_names).to eq(['PTSD (post traumatic stress disorder)'])
    end
  end
end
