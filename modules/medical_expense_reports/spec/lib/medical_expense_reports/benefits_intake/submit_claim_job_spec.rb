# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/service'
require 'medical_expense_reports/benefits_intake/submit_claim_job'
require 'medical_expense_reports/monitor'
require 'pdf_utilities/datestamp_pdf'

RSpec.describe MedicalExpenseReports::BenefitsIntake::SubmitClaimJob, :uploader_helpers,
               skip: 'TODO after schema built' do
  stub_virus_scan
  let(:job) { described_class.new }
  let(:claim) { create(:medical_expense_reports_claim) }
  let(:service) { double('service') }
  let(:monitor) { MedicalExpenseReports::Monitor.new }
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    let(:response) { double('response') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:location) { 'test_location' }
    let(:omit_esign_stamp) { true }
    let(:extras_redesign) { true }

    before do
      job.instance_variable_set(:@claim, claim)
      allow(MedicalExpenseReports::SavedClaim).to receive(:find).and_return(claim)
      allow(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      allow(claim).to receive(:persistent_attachments).and_return([])

      job.instance_variable_set(:@intake_service, service)
      allow(BenefitsIntake::Service).to receive(:new).and_return(service)
      allow(service).to receive(:uuid)
      allow(service).to receive(:request_upload)
      allow(service).to receive_messages(location:, perform_upload: response)
      allow(response).to receive(:success?).and_return true

      job.instance_variable_set(:@monitor, monitor)
    end

    context 'with medical_expense_reports_form_enabled flipper' do
      before do
        allow(UserAccount).to receive(:find).and_return(double('user_account'))
      end

      it 'processes claim when flipper is enabled' do
        allow(Flipper).to receive(:enabled?).with(:medical_expense_reports_form_enabled).and_return(true)
        allow(job).to receive(:process_document).and_return(pdf_path)

        expect(MedicalExpenseReports::SavedClaim).to receive(:find).and_return(claim)
        expect(claim).to receive(:to_pdf)
        expect(service).to receive(:perform_upload)
        expect(job).to receive(:cleanup_file_paths)

        result = job.perform(claim.id, user_account_uuid)
        expect(result).to eq(service.uuid)
      end

      it 'returns early when flipper is disabled' do
        allow(Flipper).to receive(:enabled?).with(:medical_expense_reports_form_enabled).and_return(false)

        expect(MedicalExpenseReports::SavedClaim).not_to receive(:find)
        expect(claim).not_to receive(:to_pdf)
        expect(service).not_to receive(:perform_upload)

        result = job.perform(claim.id, user_account_uuid)
        expect(result).to be_nil
      end
    end

    it 'submits the saved claim successfully' do
      allow(job).to receive(:process_document).and_return(pdf_path)

      expect(claim).to receive(:to_pdf).with(claim.id, { extras_redesign:, omit_esign_stamp: }).and_return(pdf_path)
      expect(Lighthouse::Submission).to receive(:create)
      expect(Lighthouse::SubmissionAttempt).to receive(:create)
      expect(Datadog::Tracing).to receive(:active_trace)
      expect(UserAccount).to receive(:find)

      expect(service).to receive(:perform_upload).with(
        upload_url: 'test_location', document: pdf_path, metadata: anything, attachments: []
      )
      expect(job).to receive(:cleanup_file_paths)

      job.perform(claim.id, :user_account_uuid)
    end

    it 'is unable to find user_account' do
      expect(MedicalExpenseReports::SavedClaim).not_to receive(:find)
      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        ActiveRecord::RecordNotFound,
        /Couldn't find UserAccount/
      )
    end

    it 'is unable to find saved_claim_id' do
      allow(MedicalExpenseReports::SavedClaim).to receive(:find).and_return(nil)

      expect(UserAccount).to receive(:find)

      expect(BenefitsIntake::Service).not_to receive(:new)
      expect(claim).not_to receive(:to_pdf)

      expect(job).to receive(:cleanup_file_paths)
      expect(monitor).to receive(:track_submission_retry)

      expect { job.perform(claim.id, :user_account_uuid) }.to raise_error(
        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob::MedicalExpenseReportsBenefitIntakeError,
        "Unable to find MedicalExpenseReports::SavedClaim #{claim.id}"
      )
    end
    # perform
  end

  describe '#govcio_upload' do
    let(:ibm_service) { double('ibm_service') }
    let(:response) { double('response') }

    before do
      job.instance_variable_set(:@intake_service, service)
      allow(service).to receive(:guid).and_return('test_guid')

      job.instance_variable_set(:@ibm_payload, { test: 'data' })

      allow(Ibm::Service).to receive(:new).and_return(ibm_service)
      allow(ibm_service).to receive(:upload_form).and_return(response)
      allow(response).to receive(:success?).and_return(true)
    end

    it 'uploads to IBM MMS when govcio flipper is enabled' do
      allow(Flipper).to receive(:enabled?).with(:medical_expense_reports_govcio_mms).and_return(true)

      expect(Ibm::Service).to receive(:new)
      expect(ibm_service).to receive(:upload_form).with(form: { test: 'data' }.to_json, guid: 'test_guid')

      job.send(:govcio_upload)
    end

    it 'does not upload to IBM MMS when govcio flipper is disabled' do
      allow(Flipper).to receive(:enabled?).with(:medical_expense_reports_govcio_mms).and_return(false)

      expect(Ibm::Service).not_to receive(:new)
      expect(ibm_service).not_to receive(:upload_form)

      job.send(:govcio_upload)
    end
  end

  describe '#build_ibm_payload' do
    let(:base_form_data) do
      {
        'claimantFullName' => { 'first' => 'Jane', 'middle' => 'Q', 'last' => 'Public' },
        'claimantAddress' => {
          'street' => '100 Main St',
          'street2' => 'Apt 2',
          'city' => 'City',
          'state' => 'VA',
          'postalCode' => '22206',
          'country' => 'USA'
        },
        'claimantEmail' => 'claimant@example.com',
        'careExpenses' => [
          {
            'recipient' => 'VETERAN',
            'recipientName' => 'Vet Care',
            'provider' => 'Primary Care',
            'careDate' => { 'from' => '2023-01-01', 'to' => '2023-01-31' },
            'monthlyAmount' => '1000',
            'hourlyRate' => '25',
            'weeklyHours' => '30'
          },
          {
            'recipient' => 'CHILD',
            'recipientName' => 'Child Care',
            'provider' => 'Child Provider',
            'careDate' => { 'from' => '2023-02-01', 'to' => '2023-02-28' },
            'monthlyAmount' => '1200.5',
            'hourlyRate' => '30',
            'weeklyHours' => '20'
          }
        ],
        'primaryPhone' => { 'countryCode' => 'US', 'contact' => '(555) 123-4567' },
        'veteranFullName' => { 'first' => 'John', 'middle' => 'Q', 'last' => 'Public' },
        'veteranSocialSecurityNumber' => '123456789',
        'vaFileNumber' => '987654321',
        'veteranAddress' => {
          'street' => '1 Main Street',
          'street2' => 'A1',
          'city' => 'City',
          'state' => 'VA',
          'postalCode' => '22206',
          'country' => 'USA'
        },
        'statementOfTruthSignature' => 'Jane Public',
        'dateSigned' => '2024-04-01',
        'medicalExpenses' => [
          {
            'recipient' => 'SPOUSE',
            'recipientName' => 'Spouse Expense',
            'provider' => 'Medical Lab',
            'purpose' => 'Labs',
            'paymentDate' => '2024-02-02',
            'paymentFrequency' => 'ONCE_MONTH',
            'paymentAmount' => '123456.78'
          }
        ],
        'mileageExpenses' => [
          {
            'traveler' => 'CHILD',
            'travelerName' => 'Child Traveler',
            'travelLocation' => 'HOSPITAL',
            'travelLocationOther' => 'Child Clinic',
            'travelMilesTraveled' => '45',
            'travelDate' => '2024-03-03',
            'travelReimbursementAmount' => '12345.6'
          }
        ],
        'reportingPeriod' => { 'from' => '2024-01-01', 'to' => '2024-12-31' },
        'firstTimeReporting' => false
      }
    end

    let(:form_data) { base_form_data.deep_dup }

    it 'returns the IBM data dictionary mapping' do
      payload = job.send(:build_ibm_payload, form_data)

      expect(payload).to include(
        'CLAIMANT_FIRST_NAME' => 'Jane',
        'CLAIMANT_LAST_NAME' => 'Public',
        'CLAIMANT_MIDDLE_INITIAL' => 'Q',
        'CLAIMANT_NAME' => 'Jane Q Public',
        'CLAIMANT_ADDRESS_FULL_BLOCK' => '100 Main St Apt 2 City VA 22206 USA',
        'CL_EMAIL' => 'claimant@example.com',
        'CL_PHONE_NUMBER' => '5551234567',
        'CL_INT_PHONE_NUMBER' => nil,
        'DATE_SIGNED' => '2024-04-01',
        'FORM_TYPE' => MedicalExpenseReports::FORM_TYPE_LABEL,
        'MED_EXPENSES_FROM_1' => '01/01/2024',
        'MED_EXPENSES_TO_1' => '12/31/2024',
        'USE_VA_RCVD_DATE' => false,
        'VA_FILE_NUMBER' => '987654321',
        'VETERAN_FIRST_NAME' => 'John',
        'VETERAN_LAST_NAME' => 'Public',
        'VETERAN_MIDDLE_INITIAL' => 'Q',
        'VETERAN_NAME' => 'John Q Public',
        'VETERAN_SSN' => '123456789',
        'CLAIMANT_SIGNATURE' => 'Jane Public',
        'IN_HM_VTRN_PAID_1' => true,
        'IN_HM_CHLD_PAID_2' => true,
        'IN_HM_CHLD_OTHR_NAME_2' => 'Child Care',
        'IN_HM_PROVIDER_NAME_2' => 'Child Provider',
        'IN_HM_DATE_START_2' => '02/01/2023',
        'IN_HM_AMT_PAID_2' => '1,200.50',
        'IN_HM_HRLY_RATE_2' => '30',
        'IN_HM_NBR_HRS_2' => '20',
        'MED_EXP_PAID_SPSE_1' => true,
        'CB_PAYMENT_MONTHLY1' => true,
        'MED_EXP_DATE_PAID_1' => '02/02/2024',
        'MED_EXP_AMT_PAID_1' => '123,456.78',
        'MED_EXP_PRVDR_NAME_1' => 'Medical Lab',
        'MED_EXPENSE_1' => 'Labs',
        'CHLD_RQD_TRVL_1' => true,
        'MDCL_FCLTY_NAME_1' => 'Child Clinic',
        'TTL_MLS_TRVLD_1' => '45',
        'DATE_TRVLD_1' => '03/03/2024',
        'OTHER_SRC_RMBRSD_1' => '12,345.60',
        'TRVL_CHLD_OTHR_NAME_1' => 'Child Traveler'
      )
    end

    context 'without claimantAddress data' do
      let(:form_data) do
        base_form_data.deep_dup.tap { |form| form.delete('claimantAddress') }
      end

      it 'falls back to the veteran address' do
        payload = job.send(:build_ibm_payload, form_data)

        expect(payload['CLAIMANT_ADDRESS_FULL_BLOCK']).to eq('1 Main Street A1 City VA 22206 USA')
      end
    end
  end

  describe 'helper methods' do
    describe '#build_name' do
      it 'returns nil parts when name hash is missing' do
        result = job.send(:build_name, nil)
        expect(result[:first]).to be_nil
        expect(result[:full]).to be_nil
      end

      it 'builds a full name when parts exist' do
        result = job.send(:build_name, { 'first' => 'Jane', 'last' => 'Doe' })
        expect(result[:full]).to eq('Jane Doe')
      end
    end

    describe '#build_address_block' do
      it 'returns nil when address is missing' do
        expect(job.send(:build_address_block, nil)).to be_nil
      end

      it 'joins street, city, state, postal code, and country' do
        address = {
          'street' => '100 Main St',
          'street2' => 'Apt 2',
          'city' => 'Arlington',
          'state' => 'VA',
          'postalCode' => '22206',
          'country' => 'USA'
        }
        expect(job.send(:build_address_block, address)).to eq('100 Main St Apt 2 Arlington VA 22206 USA')
      end

      it 'ignores blanks when parts are empty strings' do
        address = { 'street' => '', 'city' => 'City' }
        expect(job.send(:build_address_block, address)).to eq('City')
      end
    end

    describe '#sanitize_phone' do
      it 'returns nil when phone is nil' do
        expect(job.send(:sanitize_phone, nil)).to be_nil
      end

      it 'strips non digits' do
        expect(job.send(:sanitize_phone, '(555) 123-4567')).to eq('5551234567')
      end
    end

    describe '#international_phone_number' do
      it 'prioritizes the explicit internationalPhone field' do
        form = { 'internationalPhone' => '+52 1 234 567 890' }
        expect(job.send(:international_phone_number, form, {})).to eq('521234567890')
      end

      it 'falls back to sanitized contact when country is not US' do
        form = {}
        primary_phone = { 'countryCode' => 'MX', 'contact' => '521-234-567-890' }
        expect(job.send(:international_phone_number, form, primary_phone)).to eq('521234567890')
      end

      it 'returns nil for US phones without explicit international input' do
        form = {}
        primary_phone = { 'countryCode' => 'US', 'contact' => '555-123-4567' }
        expect(job.send(:international_phone_number, form, primary_phone)).to be_nil
      end
    end

    describe '#use_va_rcvd_date?' do
      it 'returns false when value is nil' do
        expect(job.send(:use_va_rcvd_date?, {})).to be false
      end

      it 'returns the boolean value when present' do
        expect(job.send(:use_va_rcvd_date?, { 'firstTimeReporting' => true })).to be true
        expect(job.send(:use_va_rcvd_date?, { 'firstTimeReporting' => false })).to be false
      end
    end
  end

  describe '#process_document' do
    let(:service) { double('service') }
    let(:pdf_path) { 'random/path/to/pdf' }
    let(:datestamp_pdf_double) { instance_double(PDFUtilities::DatestampPdf) }

    before do
      job.instance_variable_set(:@intake_service, service)
    end

    it 'returns a datestamp pdf path' do
      run_count = 0
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf_double)
      allow(datestamp_pdf_double).to receive(:run) {
        run_count += 1
        pdf_path
      }
      allow(service).to receive(:valid_document?).and_return(pdf_path)
      allow(File).to receive(:exist?).with(pdf_path).and_return(true)
      new_path = job.send(:process_document, 'test/path')

      expect(new_path).to eq(pdf_path)
      expect(run_count).to eq(2)
    end
    # process_document
  end

  describe '#cleanup_file_paths' do
    before do
      job.instance_variable_set(:@form_path, 'path/file.pdf')
      job.instance_variable_set(:@attachment_paths, '/invalid_path/should_be_an_array.failure')

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_file_cleanup_error)
    end

    it 'errors and logs but does not reraise' do
      expect(monitor).to receive(:track_file_cleanup_error)
      job.send(:cleanup_file_paths)
    end
  end

  describe '#send_submitted_email' do
    let(:monitor_error) { create(:monitor_error) }
    let(:notification) { double('notification') }

    before do
      job.instance_variable_set(:@claim, claim)

      allow(MedicalExpenseReports::NotificationEmail).to receive(:new).and_return(notification)
      allow(notification).to receive(:deliver).and_raise(monitor_error)

      job.instance_variable_set(:@monitor, monitor)
      allow(monitor).to receive(:track_send_email_failure)
    end

    it 'errors and logs but does not reraise' do
      expect(MedicalExpenseReports::NotificationEmail).to receive(:new).with(claim.id)
      expect(notification).to receive(:deliver).with(:submitted)
      expect(monitor).to receive(:track_send_email_failure)
      job.send(:send_submitted_email)
    end
  end

  describe 'sidekiq_retries_exhausted block' do
    let(:exhaustion_msg) do
      { 'args' => [], 'class' => 'MedicalExpenseReports::BenefitsIntake::SubmitClaimJob',
        'error_message' => 'An error occurred', 'queue' => 'low' }
    end

    before do
      allow(MedicalExpenseReports::Monitor).to receive(:new).and_return(monitor)
    end

    context 'when retries are exhausted' do
      it 'logs a distrinct error when no claim_id provided' do
        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob.within_sidekiq_retries_exhausted_block do
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end

      it 'logs a distrinct error when only claim_id provided' do
        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id] }) do
            allow(MedicalExpenseReports::SavedClaim).to receive(:find).and_return(claim)
            expect(MedicalExpenseReports::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim_id and user_account_uuid provided' do
        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, 2] }) do
            allow(MedicalExpenseReports::SavedClaim).to receive(:find).and_return(claim)
            expect(MedicalExpenseReports::SavedClaim).to receive(:find).with(claim.id)

            exhaustion_msg['args'] = [claim.id, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
        end
      end

      it 'logs a distrinct error when claim is not found' do
        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob
          .within_sidekiq_retries_exhausted_block({ 'args' => [claim.id - 1, 2] }) do
            expect(MedicalExpenseReports::SavedClaim).to receive(:find).with(claim.id - 1)

            exhaustion_msg['args'] = [claim.id - 1, 2]

            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
        end
      end
    end
  end

  # Rspec.describe
end
