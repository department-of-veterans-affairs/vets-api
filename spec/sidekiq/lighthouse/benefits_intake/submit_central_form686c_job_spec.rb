# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::BenefitsIntake::SubmitCentralForm686cJob, :uploader_helpers do
  stub_virus_scan
  subject(:job) { described_class.new }

  before do
    allow(PdfFill::Filler)
      .to receive(:fill_form) { |saved_claim, *_| "tmp/pdfs/686C-674_#{saved_claim.id || 'stub'}_final.pdf" }
  end

  let(:user) { create(:evss_user, :loa3) }
  let(:claim) { create(:dependency_claim) }
  let(:claim_v2) { create(:dependency_claim_v2) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:birth_date) { '1809-02-12' }
  let(:vet_info) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'Mark', 'middle' => 'A', 'last' => 'Webb'
        },
        'common_name' => 'Mark',
        'participant_id' => '600061742',
        'uuid' => user.uuid,
        'email' => 'vets.gov.user+228@gmail.com',
        'va_profile_email' => 'vets.gov.user+228@gmail.com',
        'ssn' => '796104437',
        'va_file_number' => '796104437',
        'icn' => user.icn,
        'birth_date' => '1950-10-04'
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }
  let(:central_mail_submission) { claim.central_mail_submission }
  let(:central_mail_submission_v2) { claim_v2.central_mail_submission }

  let(:user_struct) do
    OpenStruct.new(
      first_name: vet_info['veteran_information']['full_name']['first'],
      last_name: vet_info['veteran_information']['full_name']['last'],
      middle_name: vet_info['veteran_information']['full_name']['middle'],
      ssn: vet_info['veteran_information']['ssn'],
      email: vet_info['veteran_information']['email'],
      va_profile_email: vet_info['veteran_information']['va_profile_email'],
      participant_id: vet_info['veteran_information']['participant_id'],
      icn: vet_info['veteran_information']['icn'],
      uuid: vet_info['veteran_information']['uuid'],
      common_name: vet_info['veteran_information']['common_name']
    )
  end
  let(:encrypted_user_struct) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }

  let(:monitor) { double('monitor') }
  let(:exhaustion_msg) do
    {
      'queue' => 'default',
      'args' => [],
      'class' => 'Lighthouse::BenefitsIntake::SubmitCentralForm686cJob',
      'error_message' => 'An error occurred'
    }
  end

  context 'with va_dependents_v2 disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
    end

    describe '#perform' do
      let(:success) { true }
      let(:path) { 'tmp/pdf_path' }

      let(:lighthouse_mock) { double(:lighthouse_service) }

      before do
        expect(BenefitsIntakeService::Service).to receive(:new)
          .with(with_upload_location: true)
          .and_return(lighthouse_mock)
        expect(lighthouse_mock).to receive(:uuid).and_return('uuid')
        datestamp_double1 = double
        datestamp_double2 = double
        datestamp_double3 = double
        timestamp = claim.created_at

        expect(SavedClaim::DependencyClaim).to receive(:find).with(claim.id).and_return(claim).at_least(:once)
        expect(claim).to receive(:to_pdf).and_return('path1')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
        expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
        expect(datestamp_double2).to receive(:run).with(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true
        ).and_return('path3')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
        expect(datestamp_double3).to receive(:run).with(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true,
          timestamp:,
          page_number: 6,
          template: 'lib/pdf_fill/forms/pdfs/686C-674.pdf',
          multistamp: true
        ).and_return(path)

        data = JSON.parse('{"id":"6d8433c1-cd55-4c24-affd-f592287a7572","type":"document_upload"}')
        expect(lighthouse_mock).to receive(:upload_form).with(
          main_document: { file: path, file_name: 'pdf_path' },
          attachments: [],
          form_metadata: hash_including(file_number: '796104437')
        ).and_return(OpenStruct.new(success?: success, data:))

        expect(Common::FileHelpers).to receive(:delete_file_if_exists).with(path)

        expect(FormSubmission).to receive(:create).with(
          form_type: '686C-674',
          saved_claim: claim,
          user_account: user.user_account
        ).and_return(FormSubmission.new)
        expect(FormSubmissionAttempt).to receive(:create).with(form_submission: an_instance_of(FormSubmission),
                                                               benefits_intake_uuid: 'uuid')
      end

      context 'with an response error' do
        let(:success) { false }

        it 'raises BenefitsIntakeResponseError and updates submission to failed' do
          mailer_double = double('Mail::Message')
          allow(mailer_double).to receive(:deliver_now)
          expect(claim).to receive(:submittable_686?).and_return(true).exactly(:twice)
          expect(claim).to receive(:submittable_674?).and_return(false)
          expect { subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct) }.to raise_error(Lighthouse::BenefitsIntake::SubmitCentralForm686cJob::BenefitsIntakeResponseError) # rubocop:disable Layout/LineLength

          expect(central_mail_submission.reload.state).to eq('failed')
        end
      end

      it 'submits the saved claim and updates submission to success' do
        vanotify = double(send_email: true)
        api_key = 'fake_secret'
        callback_options = {
          callback_klass: 'Dependents::NotificationCallback',
          callback_metadata: { email_template_id: 'fake_received686',
                               email_type: :received686,
                               form_id: '686C-674',
                               claim_id: claim.id,
                               saved_claim_id: claim.id,
                               service_name: 'dependents' }
        }

        personalization = { 'confirmation_number' => claim.confirmation_number,
                            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                            'first_name' => 'MARK' }

        expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
        expect(vanotify).to receive(:send_email).with(
          {
            email_address: user_struct.va_profile_email,
            template_id: 'fake_received686',
            personalisation: personalization
          }.compact
        )

        # expect(VANotify::EmailJob).to receive(:perform_async).with(
        #   user_struct.va_profile_email,
        #   'fake_received686',
        #   { 'confirmation_number' => claim.confirmation_number,
        #     'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        #     'first_name' => 'MARK' },
        #   'fake_secret',
        #   { callback_klass: 'Dependents::NotificationCallback',
        #     callback_metadata: { email_template_id: 'fake_received686',
        #                          email_type: :received686,
        #                          form_id: '686C-674',
        #                          saved_claim_id: claim.id,
        #                          service_name: 'dependents' } }
        # )

        expect(claim).to receive(:submittable_686?).and_return(true).exactly(4).times
        expect(claim).to receive(:submittable_674?).and_return(false).at_least(:once)
        subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct)
        expect(central_mail_submission.reload.state).to eq('success')
      end
    end

    describe '#process_pdf' do
      timestamp = Time.zone.now
      subject { job.process_pdf('path1', timestamp, '686C-674') }

      it 'processes a record and add stamps' do
        datestamp_double1 = double
        datestamp_double2 = double
        datestamp_double3 = double

        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
        expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
        expect(datestamp_double2).to receive(:run).with(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true
        ).and_return('path3')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
        expect(datestamp_double3).to receive(:run).with(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true,
          timestamp:,
          page_number: 6,
          template: 'lib/pdf_fill/forms/pdfs/686C-674.pdf',
          multistamp: true
        ).and_return('path4')

        expect(subject).to eq('path4')
      end
    end

    describe '#get_hash_and_pages' do
      it 'gets sha and number of pages' do
        expect(Digest::SHA256).to receive(:file).with('path').and_return(
          OpenStruct.new(hexdigest: 'hexdigest')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('path').and_return(
          OpenStruct.new(pages: 2)
        )

        expect(described_class.new.get_hash_and_pages('path')).to eq(
          hash: 'hexdigest',
          pages: 2
        )
      end
    end

    describe '#generate_metadata' do
      subject { job.generate_metadata }

      before do
        job.instance_variable_set('@claim', claim)
        job.instance_variable_set('@form_path', 'pdf_path')
        job.instance_variable_set('@attachment_paths', ['attachment_path'])

        expect(Digest::SHA256).to receive(:file).with('pdf_path').and_return(
          OpenStruct.new(hexdigest: 'hash1')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('pdf_path').and_return(
          OpenStruct.new(pages: 1)
        )

        expect(Digest::SHA256).to receive(:file).with('attachment_path').and_return(
          OpenStruct.new(hexdigest: 'hash2')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('attachment_path').and_return(
          OpenStruct.new(pages: 2)
        )
      end

      context 'with a non us address' do
        before do
          form = JSON.parse(claim.form)
          form['dependents_application']['veteran_contact_information']['veteran_address']['country_name'] = 'AGO'
          claim.form = form.to_json
          claim.send(:remove_instance_variable, :@parsed_form)
        end

        it 'generates metadata with 00000 for zipcode' do
          expect(subject['zipCode']).to eq('00000')
        end
      end

      it 'generates the metadata', run_at: '2017-01-04 03:00:00 EDT' do
        expect(subject).to eq(
          'veteranFirstName' => vet_info['veteran_information']['full_name']['first'],
          'veteranLastName' => vet_info['veteran_information']['full_name']['last'],
          'fileNumber' => vet_info['veteran_information']['va_file_number'],
          'receiveDt' => '2017-01-04 01:00:00',
          'zipCode' => '21122',
          'uuid' => claim.guid,
          'source' => 'va.gov',
          'hashV' => 'hash1',
          'numberAttachments' => 1,
          'docType' => '686C-674',
          'numberPages' => 1,
          'ahash1' => 'hash2',
          'numberPages1' => 2
        )
      end
    end
  end

  context 'with va_dependents_v2 enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(anything).and_call_original
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
    end

    describe '#perform' do
      let(:success) { true }
      let(:path) { 'tmp/pdf_path' }

      let(:lighthouse_mock) { double(:lighthouse_service) }

      before do
        expect(BenefitsIntakeService::Service).to receive(:new)
          .with(with_upload_location: true)
          .and_return(lighthouse_mock)
        expect(lighthouse_mock).to receive(:uuid).and_return('uuid')
        datestamp_double1 = double
        datestamp_double2 = double
        datestamp_double3 = double
        timestamp = claim.created_at

        expect(SavedClaim::DependencyClaim).to receive(:find).with(claim.id).and_return(claim).at_least(:once)
        expect(claim).to receive(:to_pdf).and_return('path1')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
        expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
        expect(datestamp_double2).to receive(:run).with(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true
        ).and_return('path3')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
        expect(datestamp_double3).to receive(:run).with(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true,
          timestamp:,
          page_number: 6,
          template: 'lib/pdf_fill/forms/pdfs/686C-674.pdf',
          multistamp: true
        ).and_return(path)

        data = JSON.parse('{"id":"6d8433c1-cd55-4c24-affd-f592287a7572","type":"document_upload"}')
        expect(lighthouse_mock).to receive(:upload_form).with(
          main_document: { file: path, file_name: 'pdf_path' },
          attachments: [],
          form_metadata: hash_including(file_number: '796104437')
        ).and_return(OpenStruct.new(success?: success, data:))

        expect(Common::FileHelpers).to receive(:delete_file_if_exists).with(path)

        expect(FormSubmission).to receive(:create).with(
          form_type: '686C-674',
          saved_claim: claim,
          user_account: user.user_account
        ).and_return(FormSubmission.new)
        expect(FormSubmissionAttempt).to receive(:create).with(form_submission: an_instance_of(FormSubmission),
                                                               benefits_intake_uuid: 'uuid')
      end

      context 'with an response error' do
        let(:success) { false }

        it 'raises BenefitsIntakeResponseError and updates submission to failed' do
          mailer_double = double('Mail::Message')
          allow(mailer_double).to receive(:deliver_now)
          expect(claim).to receive(:submittable_686?).and_return(true).exactly(:twice)
          expect(claim).to receive(:submittable_674?).and_return(false)
          expect { subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct) }.to raise_error(Lighthouse::BenefitsIntake::SubmitCentralForm686cJob::BenefitsIntakeResponseError) # rubocop:disable Layout/LineLength

          expect(central_mail_submission.reload.state).to eq('failed')
        end
      end

      it 'submits the saved claim and updates submission to success' do
        vanotify = double(send_email: true)
        callback_options = {
          callback_klass: 'Dependents::NotificationCallback',
          callback_metadata: { email_template_id: 'fake_received686',
                               email_type: :received686,
                               form_id: '686C-674',
                               claim_id: claim.id,
                               saved_claim_id: claim.id,
                               service_name: 'dependents' }
        }

        personalization = { 'confirmation_number' => claim.confirmation_number,
                            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                            'first_name' => 'MARK' }

        expect(VaNotify::Service).to receive(:new).with('fake_secret', callback_options).and_return(vanotify)
        expect(vanotify).to receive(:send_email).with(
          {
            email_address: user_struct.va_profile_email,
            template_id: 'fake_received686',
            personalisation: personalization
          }.compact
        )

        # expect(VANotify::EmailJob).to receive(:perform_async).with(
        #   user_struct.va_profile_email,
        #   'fake_received686',
        #   { 'confirmation_number' => claim.confirmation_number,
        #     'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        #     'first_name' => 'MARK' },
        #   'fake_secret',
        #   { callback_klass: 'Dependents::NotificationCallback',
        #     callback_metadata: { email_template_id: 'fake_received686',
        #                          email_type: :received686,
        #                          form_id: '686C-674',
        #                          saved_claim_id: claim.id,
        #                          service_name: 'dependents' } }
        # )

        expect(claim).to receive(:submittable_686?).and_return(true).exactly(4).times
        expect(claim).to receive(:submittable_674?).and_return(false).at_least(:once)
        subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct)
        expect(central_mail_submission.reload.state).to eq('success')
      end
    end

    describe '#process_pdf' do
      timestamp = Time.zone.now
      subject { job.process_pdf('path1', timestamp, '686C-674') }

      it 'processes a record and add stamps' do
        datestamp_double1 = double
        datestamp_double2 = double
        datestamp_double3 = double

        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path1').and_return(datestamp_double1)
        expect(datestamp_double1).to receive(:run).with(text: 'VA.GOV', x: 5, y: 5, timestamp:).and_return('path2')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path2').and_return(datestamp_double2)
        expect(datestamp_double2).to receive(:run).with(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true
        ).and_return('path3')
        expect(PDFUtilities::DatestampPdf).to receive(:new).with('path3').and_return(datestamp_double3)
        expect(datestamp_double3).to receive(:run).with(
          text: 'Application Submitted on va.gov',
          x: 400,
          y: 675,
          text_only: true,
          timestamp:,
          page_number: 6,
          template: 'lib/pdf_fill/forms/pdfs/686C-674.pdf',
          multistamp: true
        ).and_return('path4')

        expect(subject).to eq('path4')
      end
    end

    describe '#get_hash_and_pages' do
      it 'gets sha and number of pages' do
        expect(Digest::SHA256).to receive(:file).with('path').and_return(
          OpenStruct.new(hexdigest: 'hexdigest')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('path').and_return(
          OpenStruct.new(pages: 2)
        )

        expect(described_class.new.get_hash_and_pages('path')).to eq(
          hash: 'hexdigest',
          pages: 2
        )
      end
    end

    describe '#generate_metadata' do
      subject { job.generate_metadata }

      before do
        job.instance_variable_set('@claim', claim)
        job.instance_variable_set('@form_path', 'pdf_path')
        job.instance_variable_set('@attachment_paths', ['attachment_path'])

        expect(Digest::SHA256).to receive(:file).with('pdf_path').and_return(
          OpenStruct.new(hexdigest: 'hash1')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('pdf_path').and_return(
          OpenStruct.new(pages: 1)
        )

        expect(Digest::SHA256).to receive(:file).with('attachment_path').and_return(
          OpenStruct.new(hexdigest: 'hash2')
        )
        expect(PdfInfo::Metadata).to receive(:read).with('attachment_path').and_return(
          OpenStruct.new(pages: 2)
        )
      end

      context 'with a non us address' do
        before do
          form = JSON.parse(claim.form)
          form['dependents_application']['veteran_contact_information']['veteran_address']['country_name'] = 'AGO'
          claim.form = form.to_json
          claim.send(:remove_instance_variable, :@parsed_form)
        end

        it 'generates metadata with 00000 for zipcode' do
          expect(subject['zipCode']).to eq('00000')
        end
      end

      it 'generates the metadata', run_at: '2017-01-04 03:00:00 EDT' do
        expect(subject).to eq(
          'veteranFirstName' => vet_info['veteran_information']['full_name']['first'],
          'veteranLastName' => vet_info['veteran_information']['full_name']['last'],
          'fileNumber' => vet_info['veteran_information']['va_file_number'],
          'receiveDt' => '2017-01-04 01:00:00',
          'zipCode' => '21122',
          'uuid' => claim.guid,
          'source' => 'va.gov',
          'hashV' => 'hash1',
          'numberAttachments' => 1,
          'docType' => '686C-674',
          'numberPages' => 1,
          'ahash1' => 'hash2',
          'numberPages1' => 2
        )
      end
    end
  end

  context 'sidekiq_retries_exhausted' do
    context 'successful exhaustion processing' do
      it 'tracks exhaustion event and sends backup submission' do
        msg = {
          'args' => [claim.id, user.uuid, encrypted_user_struct],
          'error_message' => 'Connection timeout'
        }
        error = StandardError.new('Job failed')

        # Make find return the same claim instance
        allow(SavedClaim::DependencyClaim).to receive(:find).with(claim.id).and_return(claim)

        # Mock the monitor
        monitor_double = instance_double(Dependents::Monitor)
        expect(Dependents::Monitor).to receive(:new).with(claim.id).and_return(monitor_double)

        # Expect the monitor to track the exhaustion event
        expect(monitor_double).to receive(:track_submission_exhaustion).with(msg, 'vets.gov.user+228@gmail.com')

        # Expect the claim to send a failure email
        expect(claim).to receive(:send_failure_email).with('vets.gov.user+228@gmail.com')

        # Call the sidekiq_retries_exhausted callback
        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end

    context 'failed exhaustion processing' do
      it 'logs silent failure when an exception occurs' do
        msg = {
          'args' => [claim.id, user.uuid, encrypted_user_struct],
          'error_message' => 'Connection timeout'
        }
        error = StandardError.new('Job failed')
        json_error = StandardError.new('JSON parse error')

        # Make find return the same claim instance
        allow(JSON).to receive(:parse).and_raise(json_error)

        expect(Rails.logger)
          .to receive(:error)
          .with(
            'Lighthouse::BenefitsIntake::SubmitCentralForm686cJob silent failure!',
            { e: json_error, msg:, v2: false }
          )

        expect(StatsD)
          .to receive(:increment)
          .with("#{described_class::STATSD_KEY_PREFIX}.silent_failure")

        # Call the sidekiq_retries_exhausted callback
        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end
  end
end
