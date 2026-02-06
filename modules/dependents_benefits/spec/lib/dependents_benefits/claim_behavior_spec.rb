# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_behavior'
require 'dependents_benefits/monitor'

RSpec.describe DependentsBenefits::ClaimBehavior do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:claim) { create(:dependents_claim) }
  let(:child_claim) { create(:add_remove_dependents_claim) }
  let(:student_claim) { create(:student_claim) }

  describe '#submissions_succeeded?' do
    it 'returns true when both BGS and Claims Evidence submissions succeeded' do
      allow(claim).to receive_messages(submitted_to_bgs?: true, submitted_to_claims_evidence_api?: true)

      expect(claim.submissions_succeeded?).to be true
    end

    it 'returns false when BGS submission failed or incomplete' do
      allow(claim).to receive_messages(submitted_to_bgs?: false, submitted_to_claims_evidence_api?: true)

      expect(claim.submissions_succeeded?).to be false
    end

    it 'returns false when Claims Evidence submission failed or incomplete' do
      allow(claim).to receive_messages(submitted_to_bgs?: true, submitted_to_claims_evidence_api?: false)

      expect(claim.submissions_succeeded?).to be false
    end
  end

  describe '#submitted_to_bgs?' do
    context 'when there is no BGS submission' do
      it 'returns false' do
        expect(claim.submitted_to_bgs?).to be false
      end
    end

    context 'when is a BGS submission' do
      let!(:submission) { create(:bgs_submission, saved_claim: claim) }

      it 'returns false if there are no attempts' do
        expect(claim.submitted_to_bgs?).to be false
      end

      context 'when there are attempts' do
        let!(:attempt1) { create(:bgs_submission_attempt, submission:, status: 'submitted') }
        let!(:attempt2) { create(:bgs_submission_attempt, submission:, status: 'submitted') }

        it 'returns true if the latest is submitted' do
          expect(claim.submitted_to_bgs?).to be true
        end

        it 'returns false if any latest attempt is not submitted' do
          attempt2.update(status: 'failure')
          expect(claim.submitted_to_bgs?).to be false
        end
      end
    end
  end

  describe '#submitted_to_claims_evidence_api?' do
    context 'when there is no Claims Evidence submission' do
      it 'returns false' do
        expect(claim.submitted_to_claims_evidence_api?).to be false
      end
    end

    context 'when is a Claims Evidence submission' do
      let!(:submission) { create(:claims_evidence_submission, saved_claim: claim) }

      it 'returns false if there are no attempts' do
        expect(claim.submitted_to_claims_evidence_api?).to be false
      end

      context 'when there are attempts' do
        let!(:attempt1) { create(:claims_evidence_submission_attempt, submission:, status: 'accepted') }
        let!(:attempt2) { create(:claims_evidence_submission_attempt, submission:, status: 'accepted') }

        it 'returns true if the latest is submitted' do
          expect(claim.submitted_to_claims_evidence_api?).to be true
        end

        it 'returns false if any latest attempt is not submitted' do
          attempt2.update(status: 'failed')
          expect(claim.submitted_to_claims_evidence_api?).to be false
        end
      end
    end
  end

  describe '#to_pdf' do
    it 'does not fail' do
      expect(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).with(child_claim, nil).and_call_original
      expect { child_claim.to_pdf }.not_to raise_error
    end

    context 'when veteran_information is missing' do
      before do
        allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original

        child_claim.parsed_form.delete('veteran_information')
        child_claim.parsed_form['dependents_application'].delete('veteran_information')
      end

      it 'raises an error in the PDF filler' do
        expect { child_claim.to_pdf }.to raise_error(DependentsBenefits::MissingVeteranInfoError)
      end
    end

    context 'with a student claim' do
      before do
        allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original
      end

      it 'builds the pdf correctly' do
        expect(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).with(student_claim, nil).and_call_original
        expect { student_claim.to_pdf }.not_to raise_error
      end

      context 'when veteran_information is missing' do
        before do
          allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original

          student_claim.parsed_form.delete('veteran_information')
        end

        it 'raises an error in the PDF filler' do
          expect { student_claim.to_pdf }.to raise_error(DependentsBenefits::MissingVeteranInfoError)
        end
      end
    end
  end

  describe 'validation behavior' do
    context 'when the form matches the schema' do
      it 'returns true' do
        expect(claim.form_matches_schema).to be true
      end
    end

    context 'when the form does not match the schema' do
      let(:monitor_double) { instance_double(DependentsBenefits::Monitor) }

      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim)
          .to receive(:validate_schema)
          .and_return([
                        { fragment: '#/veteran_information', message: 'is missing' }
                      ])
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim)
          .to receive(:validate_form)
          .and_return([])
        allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor_double)
        allow(monitor_double).to receive(:track_error_event)
      end

      it 'returns false and adds errors' do
        expect(claim.form_matches_schema).to be false
        expect(monitor_double).to have_received(:track_error_event).with(
          'Dependents Benefits schema failed validation.',
          'api.dependents_claim.schema_error',
          form_id: claim.form_id,
          errors: [{ fragment: '#/veteran_information', message: 'is missing' }]
        ).at_least(:once)
      end
    end
  end

  describe '#form_schema' do
    context 'when the schema file cannot be loaded' do
      let(:monitor_double) { instance_double(DependentsBenefits::Monitor) }
      let(:error_message) { 'No such file or directory' }
      let(:form_id) { '21-686C' }

      before do
        allow(claim).to receive(:monitor).and_return(monitor_double)
        allow(monitor_double).to receive(:track_error_event)
        allow(File).to receive(:read).and_raise(Errno::ENOENT, error_message)
      end

      it 'returns nil and tracks the error' do
        expect(claim.form_schema(form_id)).to be_nil
        expect(monitor_double).to have_received(:track_error_event).with(
          'Dependents Benefits form schema could not be loaded.',
          'api.dependents_claim.schema_load_error',
          form_id:,
          error: "No such file or directory - #{error_message}"
        )
      end
    end
  end

  describe '#pension_related_submission?' do
    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(false)
      end

      it 'returns false' do
        expect(child_claim.pension_related_submission?).to be false
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(true)
      end

      context 'when the claim is pension related' do
        it 'returns true' do
          expect(child_claim.pension_related_submission?).to be true
        end
      end

      context 'when the claim is not pension related' do
        before do
          child_claim.parsed_form['dependents_application'].delete('household_income')
        end

        it 'returns false' do
          expect(child_claim.pension_related_submission?).to be false
        end
      end
    end
  end

  describe '#folder_identifier' do
    context 'when ssn is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = '123-45-6789'
        claim.parsed_form['veteran_information']['participant_id'] = nil
        claim.parsed_form['veteran_information']['icn'] = nil
      end

      it 'includes ssn in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:SSN:123-45-6789')
      end
    end

    context 'when participant_id is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = nil
        claim.parsed_form['veteran_information']['participant_id'] = 'P123456789'
        claim.parsed_form['veteran_information']['icn'] = nil
      end

      it 'includes participant_id in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:PARTICIPANT_ID:P123456789')
      end
    end

    context 'when icn is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = nil
        claim.parsed_form['veteran_information']['participant_id'] = nil
        claim.parsed_form['veteran_information']['icn'] = 'ICN123456789'
      end

      it 'includes icn in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:ICN:ICN123456789')
      end
    end
  end

  describe '#claim_form_type' do
    context 'when both 686 and 674 forms are submittable' do
      it 'returns 686c-674' do
        expect(claim.claim_form_type).to eq('686c-674')
      end
    end

    context 'when only 686 form is submittable' do
      it 'returns 21-686c' do
        expect(child_claim.claim_form_type).to eq('21-686c')
      end
    end

    context 'when only 674 form is submittable' do
      it 'returns 21-674' do
        expect(student_claim.claim_form_type).to eq('21-674')
      end
    end

    context 'when form type is unknown' do
      let(:monitor_double) { instance_double(DependentsBenefits::Monitor) }

      before do
        allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor_double)
        allow(claim).to receive(:submittable_686?).and_raise(StandardError.new('Unknown form type'))
        allow(monitor_double).to receive(:track_unknown_claim_type)
      end

      it 'returns nil and tracks the unknown claim type' do
        expect(claim.claim_form_type).to be_nil
        expect(monitor_double).to have_received(:track_unknown_claim_type)
      end
    end
  end

  describe '#add_veteran_info' do
    it 'merges veteran information into the parsed form' do
      veteran_info = {
        'veteran_information' => {
          'ssn' => '987-65-4321',
          'participant_id' => 'P987654321',
          'icn' => 'ICN987654321'
        }
      }

      claim.add_veteran_info(veteran_info)

      expect(claim.parsed_form['veteran_information']['ssn']).to eq('987-65-4321')
      expect(claim.parsed_form['veteran_information']['participant_id']).to eq('P987654321')
      expect(claim.parsed_form['veteran_information']['icn']).to eq('ICN987654321')
    end
  end
end
