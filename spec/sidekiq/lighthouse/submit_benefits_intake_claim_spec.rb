# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::SubmitBenefitsIntakeClaim, :uploader_helpers do
  include StatsD::Instrument::Helpers
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:fake_saved_claim) }

  describe '#perform' do
    context 'with SavedClaim::Test' do
      let(:service) { double('service') }
      let(:response) { double('response') }
      let(:pdf_path) { 'random/path/to/pdf' }
      let(:location) { 'test_location' }
      let(:notification) { double('notification') }

      before do
        stub_const('SavedClaim::Test::FORM', '10-10EZ')
        job.instance_variable_set(:@claim, claim)
        allow(SavedClaim).to receive(:find).and_return(claim)

        allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
        allow(service).to receive(:uuid)
        allow(service).to receive_messages(location:, upload_doc: response)
      end

      it 'submits the saved claim successfully' do
        allow(service).to receive(:valid_document?).and_return(pdf_path)
        allow(response).to receive(:success?).and_return(true)

        expect(job).to receive(:create_form_submission_attempt)
        expect(job).to receive(:generate_metadata).once.and_call_original
        expect(job).to receive(:send_confirmation_email).once
        expect(service).to receive(:upload_doc)

        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.success')

        job.perform(claim.id)

        expect(response.success?).to be(true)
        expect(claim.form_submissions).not_to be_nil
        expect(claim.business_line).not_to be_nil
      end

      it 'submits and gets a response error' do
        allow(service).to receive(:valid_document?).and_return(pdf_path)
        allow(response).to receive_messages(success?: false, body: 'There was an error submitting the claim')
        expect(job).to receive(:create_form_submission_attempt)
        expect(job).to receive(:generate_metadata).once
        expect(service).to receive(:upload_doc)
        expect(Rails.logger).to receive(:warn)
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.failure')
        expect { job.perform(claim.id) }.to raise_error(Lighthouse::SubmitBenefitsIntakeClaim::BenefitsIntakeClaimError)
        expect(response.success?).to be(false)
      end

      it 'handles an invalid document' do
        allow(service).to receive(:valid_document?).and_raise(BenefitsIntakeService::Service::InvalidDocumentError)
        expect(Rails.logger).to receive(:warn)
        expect(StatsD).to receive(:increment).with(
          'worker.lighthouse.submit_benefits_intake_claim.document_upload_error'
        )
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.failure')
        expect { job.perform(claim.id) }.to raise_error(BenefitsIntakeService::Service::InvalidDocumentError)
      end

      it 'saves user_account_id on the form submission' do
        user_account = UserAccount.create!(id: SecureRandom.uuid)
        claim.update!(user_account_id: user_account.id)

        allow(service).to receive(:valid_document?).and_return(pdf_path)
        allow(response).to receive(:success?).and_return(true)

        job.perform(claim.id)

        expect(claim.form_submissions.last.user_account_id).to eq(user_account.id)
      end
    end

    context 'With SavedClaim::Form210779' do
      let(:va210779claim) { create(:va210779) }
      let(:job779) { described_class.new }

      it 'submits the saved claim successfully' do
        VCR.use_cassette('lighthouse/benefits_claims/submit210779') do
          Sidekiq::Testing.inline! do
            expect(job779).to receive(:create_form_submission_attempt)
            expect(job779).to receive(:generate_metadata).once.and_call_original
            expect(job779).to receive(:send_confirmation_email).once

            metrics = capture_statsd_calls do
              job779.perform(va210779claim.id)
            end
            expect(metrics.collect(&:source)).to include(
              'saved_claim.create:1|c|#form_id:21-0779,doctype:222',
              'worker.lighthouse.submit_benefits_intake_claim.success:1|c'
            )
            expect(va210779claim.form_submissions).not_to be_nil
            expect(va210779claim.business_line).not_to be_nil
          end
        end
      end
    end
  end

  describe '#process_record' do
    let(:path) { 'tmp/pdf_path' }
    let(:service) { double('service') }

    before do
      allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
      job.init(claim.id)
    end

    it 'processes a 21P-530EZ record and add stamps' do
      record = double
      allow(record).to receive_messages({ created_at: claim.created_at })
      datestamp_double1 = double
      datestamp_double2 = double
      double
      timestamp = claim.created_at

      expect(record).to receive(:to_pdf).and_return('path1')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
      expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5,
                                                      timestamp:).and_return('path2')
      expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
      expect(datestamp_double2).to receive(:run).with(
        text: 'FDC Reviewed - va.gov Submission',
        x: 400,
        y: 770,
        text_only: true
      ).and_return('path3')

      expect(service).to receive(:valid_document?).and_return(path)

      expect(job.process_record(record)).to eq(path)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    it 'logs a distinct error when retries are exhausted' do
      Lighthouse::SubmitBenefitsIntakeClaim.within_sidekiq_retries_exhausted_block do
        expect(Rails.logger).to receive(:error).exactly(:once)
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.exhausted')
      end
    end
  end

  describe '#govcio_upload' do
    let(:ibm_service) { double('Ibm::Service') }
    let(:lighthouse_service) { double('BenefitsIntakeService::Service', uuid: '123-456-789') }
    let(:form21p530a_claim) { create(:va21p530a) }

    before do
      job.instance_variable_set(:@claim, form21p530a_claim)
      job.instance_variable_set(:@lighthouse_service, lighthouse_service)
      allow(Ibm::Service).to receive(:new).and_return(ibm_service)
    end

    context 'when form responds to to_ibm and flipper is enabled' do
      before do
        allow(form21p530a_claim).to receive(:to_ibm).and_return({ 'VETERAN_NAME' => 'John Doe' })
        job.instance_variable_set(:@ibm_payload, form21p530a_claim.to_ibm)
        allow(Flipper).to receive(:enabled?).with(:form_21p_530a_govcio_mms).and_return(true)
      end

      it 'uploads to IBM MMS successfully' do
        expect(Rails.logger).to receive(:info).with(
          'Lighthouse::SubmitBenefitsIntakeClaim uploading to IBM MMS',
          anything
        )
        expect(ibm_service).to receive(:upload_form).with(
          form: '{"VETERAN_NAME":"John Doe"}',
          guid: '123-456-789'
        )
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.govcio_upload.success')

        job.send(:govcio_upload)
      end

      it 'handles upload errors gracefully' do
        allow(ibm_service).to receive(:upload_form).and_raise(StandardError, 'Upload failed')
        expect(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:error).with(
          'Lighthouse::SubmitBenefitsIntakeClaim IBM MMS upload error: Upload failed',
          anything
        )
        expect(StatsD).to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.govcio_upload.failure')

        job.send(:govcio_upload)
      end
    end

    context 'when flipper is disabled' do
      before do
        allow(form21p530a_claim).to receive(:to_ibm).and_return({ 'VETERAN_NAME' => 'John Doe' })
        job.instance_variable_set(:@ibm_payload, form21p530a_claim.to_ibm)
        allow(Flipper).to receive(:enabled?).with(:form_21p_530a_govcio_mms).and_return(false)
      end

      it 'does not upload to IBM MMS' do
        expect(ibm_service).not_to receive(:upload_form)
        expect(StatsD).not_to receive(:increment).with('worker.lighthouse.submit_benefits_intake_claim.govcio_upload.success')

        job.send(:govcio_upload)
      end
    end

    context 'when form does not respond to to_ibm' do
      before do
        job.instance_variable_set(:@ibm_payload, nil)
      end

      it 'does not attempt upload' do
        expect(Flipper).not_to receive(:enabled?)
        expect(ibm_service).not_to receive(:upload_form)

        job.send(:govcio_upload)
      end
    end

    context 'with different form IDs' do
      let(:form210779_claim) { create(:va210779) }

      it 'uses correct flipper key for form 21-0779' do
        job.instance_variable_set(:@claim, form210779_claim)
        allow(form210779_claim).to receive(:to_ibm).and_return({ 'VETERAN_NAME' => 'Jane Doe' })
        job.instance_variable_set(:@ibm_payload, form210779_claim.to_ibm)

        expect(Flipper).to receive(:enabled?).with(:form_21_0779_govcio_mms).and_return(false)

        job.send(:govcio_upload)
      end
    end
  end
  # Rspec.describe
end
