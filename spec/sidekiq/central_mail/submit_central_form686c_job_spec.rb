# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CentralMail::SubmitCentralForm686cJob, :uploader_helpers do
  stub_virus_scan
  subject(:job) { described_class.new }

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
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

      expect(SavedClaim::DependencyClaim).to receive(:find).with(claim.id).and_return(claim)
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
        benefits_intake_uuid: 'uuid',
        saved_claim: claim,
        user_account: nil
      ).and_return(FormSubmission.new)
      expect(FormSubmissionAttempt).to receive(:create).with(form_submission: an_instance_of(FormSubmission),
                                                             benefits_intake_uuid: 'uuid')
    end

    context 'with an response error' do
      let(:success) { false }

      it 'raises CentralMailResponseError and updates submission to failed' do
        mailer_double = double('Mail::Message')
        allow(mailer_double).to receive(:deliver_now)
        expect(claim).to receive(:submittable_686?).and_return(true).exactly(:twice)
        expect(claim).to receive(:submittable_674?).and_return(false)
        expect { subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct) }.to raise_error(CentralMail::SubmitCentralForm686cJob::CentralMailResponseError) # rubocop:disable Layout/LineLength

        expect(central_mail_submission.reload.state).to eq('failed')
      end
    end

    it 'submits the saved claim and updates submission to success' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user_struct.va_profile_email,
        'fake_template_id',
        {
          'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
          'first_name' => 'MARK'
        }
      )
      expect(claim).to receive(:submittable_686?).and_return(true).exactly(:twice)
      expect(claim).to receive(:submittable_674?).and_return(false)
      subject.perform(claim.id, encrypted_vet_info, encrypted_user_struct)
      expect(central_mail_submission.reload.state).to eq('success')
    end
  end

  describe '#to_faraday_upload' do
    it 'converts a file to faraday upload object' do
      file_path = 'tmp/foo'
      expect(Faraday::UploadIO).to receive(:new).with(
        file_path,
        'application/pdf'
      )
      described_class.new.to_faraday_upload(file_path)
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

    describe 'sidekiq_retries_exhausted block' do
      it 'logs a distinct error when retries are exhausted' do
        CentralMail::SubmitCentralForm686cJob.within_sidekiq_retries_exhausted_block do
          expect(Rails.logger).to receive(:error).exactly(:once)
          expect(StatsD).to receive(:increment).with('worker.submit_686c_674_backup_submission.exhausted')
        end
      end
    end
  end
end
