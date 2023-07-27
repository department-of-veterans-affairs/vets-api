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
end
