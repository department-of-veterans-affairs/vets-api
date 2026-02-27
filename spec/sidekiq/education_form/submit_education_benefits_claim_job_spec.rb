# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::SubmitEducationBenefitsClaimJob, form: :education_benefits, type: :model do
  subject { described_class.new }

  let(:claim) { create(:va0989) }
  let(:stub_service) { double('BenefitsIntake::Service') }
  let(:stub_monitor) { double('EducationBenefitsClaims::Monitor') }

  before do
    allow(BenefitsIntake::Service).to receive(:new).and_return(stub_service)
    allow(stub_service).to receive(:request_upload)
    allow(stub_service).to receive_messages(valid_document?: 'tmp/test.pdf', location: 'http://example.com/upload',
                                            uuid: 'acde070d-8c4c-4f0d-9d8a-162843c10333')
    allow(claim).to receive(:to_pdf).and_return('tmp/test.pdf')

    allow(EducationBenefitsClaims::Monitor).to receive(:new).and_return(stub_monitor)
    allow(stub_monitor).to receive(:track_submission_success)
    allow(stub_monitor).to receive(:track_submission_retry)
    allow(stub_monitor).to receive(:track_submission_begun)
    allow(stub_monitor).to receive(:track_submission_attempted)
  end

  describe '#perform' do
    context 'with a missing claim' do
      it 'raises an error' do
        expect { subject.perform(123) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with an invalid form type' do
      let(:claim) { create(:va0803) }

      it 'raises an error' do
        expect { subject.perform(claim.id) }.to raise_error(EducationForm::SubmitEducationBenefitsClaimJob::EducationBenefitClaimIntakeError)
      end
    end

    context 'with a pending lighthouse submission' do
      before do
        create(:lighthouse_submission, :pending, saved_claim: claim)
      end

      it 'returns and does nothing' do
        expect(stub_service).not_to receive(:request_upload)
        subject.perform(claim.id)
      end
    end

    context 'with an invalid document' do
      before do
        allow(stub_service).to receive(:valid_document?).and_raise(BenefitsIntake::Service::InvalidDocumentError)
      end

      it 'returns and does nothing' do
        expect { subject.perform(claim.id) }.to raise_error(BenefitsIntake::Service::InvalidDocumentError)
      end
    end

    context 'with a failed upload' do
      before do
        allow(stub_service).to receive(:perform_upload).and_return(OpenStruct.new(success?: false,
                                                                                  to_s: 'error occurred'))
      end

      it 'returns and does nothing' do
        expect do
          subject.perform(claim.id)
        end.to raise_error(
          EducationForm::SubmitEducationBenefitsClaimJob::EducationBenefitClaimIntakeError, 'error occurred'
        )
      end

      it 'marks the submission attempt as failed and calls the monitor' do
        expect(stub_monitor).to receive(:track_submission_retry)
        expect do
          subject.perform(claim.id)
        rescue
          # pass
        end.to change(Lighthouse::SubmissionAttempt, :count).by(1)

        expect(Lighthouse::SubmissionAttempt.first.status).to eq('failure')
      end
    end

    context 'with a successful upload' do
      before do
        allow(stub_service).to receive(:perform_upload).and_return(OpenStruct.new(success?: true))
      end

      it 'returns the upload uuid' do
        expect(subject.perform(claim.id)).to eq('acde070d-8c4c-4f0d-9d8a-162843c10333')
      end

      it 'marks the submission attempt as pending' do
        expect { subject.perform(claim.id) }.to change(Lighthouse::SubmissionAttempt, :count).by(1)
        expect(Lighthouse::SubmissionAttempt.first.status).to eq('pending')
      end

      it 'calls the monitor' do
        expect(stub_monitor).to receive(:track_submission_success)
        expect(stub_monitor).to receive(:track_submission_begun)
        expect(stub_monitor).to receive(:track_submission_attempted)
        subject.perform(claim.id)
      end
    end
  end

  describe 'exhaustion block' do
    context 'with no claim found' do
      it 'calls the monitor' do
        described_class.within_sidekiq_retries_exhausted_block({ 'args' => ['123'] }) do
          expect(stub_monitor).to receive(:track_submission_exhaustion).with(anything, nil)
        end
      end
    end

    context 'with claim found' do
      it 'calls the monitor' do
        described_class.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
          expect(stub_monitor).to receive(:track_submission_exhaustion).with(anything, claim)
        end
      end
    end
  end
end
