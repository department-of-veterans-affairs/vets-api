# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

require 'simple_forms_api/benefits_intake/submission'
require 'lighthouse/benefits_intake/service'
require 'persistent_attachments/military_records'

RSpec.describe SimpleFormsApi::BenefitsIntake::Submission do
  forms = [
    'vba_20_10206',
    # 'vba_20_10207-non-veteran',
    # 'vba_20_10207-veteran',
    'vba_20_10207',
    'vba_21_0845',
    'vba_21_0966',
    'vba_21_0972',
    'vba_21_10210',
    'vba_21_4138',
    'vba_21_4142',
    'vba_21p_0847',
    # 'vba_26_4555', # TODO: Restore this test when we release 26-4555 to production.
    'vba_40_0247',
    'vba_40_10007'
  ]

  unauthenticated_forms = %w[
    vba_21_10210
    vba_21p_0847
    vba_40_0247
    vba_40_10007
  ]
  authenticated_forms = forms - unauthenticated_forms

  let(:mock_s3_client) { instance_double(SimpleFormsApi::FormRemediation::S3Client) }
  let(:mock_lighthouse_service) { instance_double(BenefitsIntake::Service) }
  let(:pdf_url) { 'https://s3.com/presigned-goodness' }
  let(:file_seed) { 'unique-file-seed' }
  let(:seed_tmp_directory) { "tmp/#{file_seed}" }
  let(:metadata_file) { "#{seed_tmp_directory}.SimpleFormsApi.metadata.json" }
  let(:location_url) { 'https://sandbox-api.va.gov/services_user_content/vba_documents/id-path-doesnt-matter' }
  let(:confirmation_number) { SecureRandom.uuid }
  let(:upload_response) { OpenStruct.new(status: 200, confirmation_number:) }
  let(:filler) { instance_double(SimpleFormsApi::PdfFiller) }

  before do
    allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:new).and_return(mock_s3_client)
    allow(mock_s3_client).to receive(:upload).and_return(pdf_url)
    allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)
    allow(Common::FileHelpers).to receive(:random_file_path).and_return(seed_tmp_directory)
    allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_wrap_original do |original_method, *args|
      original_method.call(args[0], file_seed)
    end
    allow(BenefitsIntake::Service).to receive(:new).and_return(mock_lighthouse_service)
    allow(mock_lighthouse_service).to(
      receive_messages(request_upload: [location_url, confirmation_number], perform_upload: upload_response)
    )
    allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
    allow(filler).to receive(:generate).and_return(file_path)
    Flipper.disable(:simple_forms_email_confirmations)
    Flipper.enable(:submission_pdf_s3_upload)
  end

  after do
    Common::FileHelpers.delete_file_if_exists(metadata_file)
    Flipper.enable(:simple_forms_email_confirmations)
    Flipper.disable(:submission_pdf_s3_upload)
  end

  describe '#submit' do
    shared_examples 'form submission' do |form, is_authenticated|
      subject(:submit) { instance.submit }

      let(:fixture_path) { %w[modules simple_forms_api spec fixtures] }
      let(:form_json_path) { Rails.root.join(*fixture_path, 'form_json', "#{form}.json") }
      let(:file_path) { Rails.root.join(*fixture_path, 'pdfs', "#{form}.pdf").to_s }
      let(:params) { JSON.parse(form_json_path.read) }
      let(:current_user) { build(:user, :loa3) }
      let(:instance) { described_class.new(current_user, params) }
      let(:created_at) { 1.minute.ago }

      context "for #{form}" do
        let(:form_class) { "SimpleFormsApi::#{form.titleize.gsub(' ', '')}".constantize }
        let(:mock_form_instance) { instance_double(form_class) }
        let(:mock_submission) do
          create(:form_submission, :pending, form_type: params['form_number'], form_data: params.to_s, created_at:)
        end
        let(:mock_submission_attempt) { create(:form_submission_attempt, form_submission: mock_submission) }
        let(:in_progress_form) do
          return nil unless is_authenticated

          create(:in_progress_form, user_uuid: current_user.uuid, form_id: params['form_number'])
        end

        before do
          allow(form_class).to receive(:new).and_return(mock_form_instance)
          allow(mock_form_instance).to receive_messages(
            {
              track_user_identity: true,
              metadata: in_progress_form&.metadata || {},
              zip_code_is_us_based: true
            }.tap do |messages|
              if %w[vba_40_0247 vba_40_10007].include?(form)
                messages.merge(
                  {
                    get_attachments: ['attachment1.pdf', 'attachment2.png'],
                    handle_attachments: ['attachment1.pdf', 'attachment2.png']
                  }
                )
              end
            end
          )
          allow(FormSubmission).to receive(:create).and_return(mock_submission)
          allow(FormSubmissionAttempt).to receive(:create).and_return(mock_submission_attempt)
          submit
        end

        it 'validates metadata' do
          expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate)
        end

        it 'responds with status OK' do
          expect(submit[:status]).to eq(200)
        end

        it 'responds with the correct JSON payload' do
          expect(submit[:json]).to eq(confirmation_number:, pdf_url:)
        end

        it 'creates a FormSubmissionAttempt record' do
          expect(FormSubmissionAttempt).to have_received(:create).with(
            form_submission: mock_submission,
            benefits_intake_uuid: confirmation_number
          )
        end

        it 'sends the PDF to the S3 bucket' do
          submit
          expect(mock_s3_client).to have_received(:upload)
        end
      end
    end

    describe 'unauthenticated forms' do
      unauthenticated_forms.each do |form|
        include_examples 'form submission', form, false
      end
    end

    describe 'authenticated forms' do
      authenticated_forms.each do |form|
        include_examples 'form submission', form, true
      end
    end
  end
end
