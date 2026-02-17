# frozen_string_literal: true

require 'rails_helper'

require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission
require 'sidekiq/form526_backup_submission_process/submit'

RSpec.describe Sidekiq::Form526BackupSubmissionProcess::Processor do
  subject { described_class }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  before do
    allow_any_instance_of(BenefitsIntakeService::Utilities::ConvertToPdf)
      .to receive(:converted_filename)
      .and_return('tmp/converted_file.pdf')
  end

  context 'veteran with a foreign address' do
    describe 'submission and document metadata' do
      before do
        allow(Settings.form526_backup).to receive(:enabled).and_return(true)
      end

      let!(:submission) { create(:form526_submission, :with_non_us_address) }

      it 'sets the submission metadata zip code to a default value' do
        instance = subject.new(submission.id, get_upload_location_on_instantiation: false)
        expect(instance.zip).to eq('00000')
      end
    end
  end

  describe '#choose_provider' do
    let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
    let(:user_account) { user.user_account }
    let(:icn) { user_account.icn }
    let(:submission) { create(:form526_submission, user_account:, submit_endpoint: 'claims_api') }

    it 'delegates to the ApiProviderFactory with the correct data' do
      auth_headers = {}
      expect(ApiProviderFactory).to receive(:call).with(
        {
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: { auth_headers:, breakered: true },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: }),
          feature_toggle: nil
        }
      )

      subject
        .new(submission.id, get_upload_location_on_instantiation: false)
        .choose_provider(auth_headers, ApiProviderFactory::API_PROVIDER[:lighthouse])
    end

    describe '#get_uploads' do
      let!(:submission) { create(:form526_submission, :with_everything, user_account:) }
      let!(:upload_data) { submission.form[Form526Submission::FORM_526_UPLOADS] }
      let(:mock_random_file_path) { 'tmp/mock_random_file_path' }
      let(:mock_timestamp) { 1_234_567_890 }

      before do
        allow(Common::FileHelpers).to receive(:random_file_path).and_return(mock_random_file_path)
        upload_data.each do |ud|
          filename = ud['name']
          file_path = Rails.root.join('spec', 'fixtures', 'files', filename)
          file = Rack::Test::UploadedFile.new(file_path, 'application/pdf')
          sea = SupportingEvidenceAttachment.find_or_create_by(guid: ud['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
        end
      end

      it 'calls process with correct filename path' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              processor = described_class.new(submission.id)
              processed_files = processor.get_uploads
              processed_files.each do |processed_file|
                # Filenames are shortened at upload time by SupportingEvidenceAttachmentUploader,
                # and the resulting filename (path component) should be reasonably short (<= 255 characters).
                expect(processed_file[:file]).to match(%r{^tmp/.+\.pdf$})
                expect(File.basename(processed_file[:file]).length).to be <= 255
              end
            end
          end
        end
      end

      context 'when uploads have long original filenames that were shortened' do
        let(:long_filename) { "#{'a' * 200}.pdf" }

        before do
          # Override the first upload with a long filename
          first_upload = upload_data.first
          fixture_file_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
          file = Rack::Test::UploadedFile.new(fixture_file_path, 'application/pdf')
          allow(file).to receive(:original_filename).and_return(long_filename)

          sea = SupportingEvidenceAttachment.find_by(guid: first_upload['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
        end

        it 'retrieves files without ENAMETOOLONG error' do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                processor = described_class.new(submission.id)
                expect { processor.get_uploads }.not_to raise_error
              end
            end
          end
        end
      end
    end

    it 'pulls from the correct Lighthouse provider according to the startedFormVersion' do
      allow_any_instance_of(LighthouseGeneratePdfProvider).to receive(:generate_526_pdf)
        .and_return(Faraday::Response.new(
                      status: 200, body: '526pdf'
                    ))

      expect(ApiProviderFactory).to receive(:call).with(
        {
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: { auth_headers: submission.auth_headers, breakered: true },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: }),
          feature_toggle: nil
        }
      ).and_call_original

      subject
        .new(submission.id, get_upload_location_on_instantiation: false)
        .get_form526_pdf
    end

    describe '#get_form526_pdf claimDate handling' do
      let(:created_at_time) { Time.zone.local(2023, 7, 15, 14, 30, 0) }
      let(:submission_with_claim_date) { create(:form526_submission, :with_everything, user_account:) }
      let(:submission_without_claim_date) { create(:form526_submission, user_account:) }
      let!(:captured_form_json) { {} }

      before do
        # Mock the response so we don't make actual API calls
        klass = LighthouseGeneratePdfProvider
        allow_any_instance_of(klass).to receive(:generate_526_pdf) do |_instance, form_json, _transaction_id|
          # Capture the form_json that's being sent (mutate the existing hash rather than reassigning)
          captured_form_json.replace(JSON.parse(form_json))
          Faraday::Response.new(status: 200, body: '526pdf')
        end
      end

      context 'when submission has no claimDate in the form' do
        it 'sets claimDate to the formatted submission created_at date' do
          # Set the created_at time for the submission
          submission_without_claim_date.update!(created_at: created_at_time)

          processor = subject.new(submission_without_claim_date.id, get_upload_location_on_instantiation: false)
          processor.get_form526_pdf

          # Verify claimDate was set to the formatted created_at date
          expect(captured_form_json['form526']['claimDate']).to eq('2023-07-15')
        end
      end

      context 'when submission has nil claimDate in the form' do
        it 'sets claimDate to the formatted submission created_at date' do
          # Modify the form to have nil claimDate
          form_data = JSON.parse(submission_with_claim_date.form_json)
          form_data['form526']['claimDate'] = nil
          submission_with_claim_date.update!(
            form_json: form_data.to_json,
            created_at: created_at_time
          )

          processor = subject.new(submission_with_claim_date.id, get_upload_location_on_instantiation: false)
          processor.get_form526_pdf

          # Verify claimDate was set to the formatted created_at date
          expect(captured_form_json['form526']['claimDate']).to eq('2023-07-15')
        end
      end

      context 'when submission has empty string claimDate in the form' do
        it 'sets claimDate to the formatted submission created_at date' do
          # Modify the form to have empty claimDate
          form_data = JSON.parse(submission_with_claim_date.form_json)
          form_data['form526']['claimDate'] = ''
          submission_with_claim_date.update!(
            form_json: form_data.to_json,
            created_at: created_at_time
          )

          processor = subject.new(submission_with_claim_date.id, get_upload_location_on_instantiation: false)
          processor.get_form526_pdf

          # Verify claimDate was set to the formatted created_at date
          expect(captured_form_json['form526']['claimDate']).to eq('2023-07-15')
        end
      end

      it 'formats the submission created_at date as YYYY-MM-DD' do
        # Test different created_at dates to ensure proper formatting
        test_dates = [
          Time.zone.local(2023, 1, 1),    # New Year's Day
          Time.zone.local(2023, 12, 31),  # New Year's Eve
          Time.zone.local(2023, 2, 28),   # End of February (non-leap year)
          Time.zone.local(2024, 2, 29)    # Leap year February 29th
        ]

        expected_formats = %w[2023-01-01 2023-12-31 2023-02-28 2024-02-29]

        test_dates.each_with_index do |test_date, index|
          submission_without_claim_date.update!(created_at: test_date)

          processor = subject.new(submission_without_claim_date.id, get_upload_location_on_instantiation: false)
          processor.get_form526_pdf

          expect(captured_form_json['form526']['claimDate']).to eq(expected_formats[index])
        end
      end
    end
  end

  describe '#get_form0781_pdf' do
    context 'generates a 0781 version 1 pdf' do
      let(:submission) { create(:form526_submission, :with_0781, submit_endpoint: 'benefits_intake_api') } # rubocop:disable Naming/VariableNumber

      it 'generates a 0781 v1 pdf and a 0781a pdf' do
        form0781_pdfs = subject
                        .new(submission.id, get_upload_location_on_instantiation: false)
                        .get_form0781_pdf
        expect(form0781_pdfs.count).to eq(2)
        expect(form0781_pdfs.first[:type]).to eq('21-0781')
        expect(form0781_pdfs.last[:type]).to eq('21-0781a')
      end
    end

    context 'generates a 0781 version 2 pdf' do
      let(:submission) { create(:form526_submission, :with_0781v2, submit_endpoint: 'benefits_intake_api') }

      it 'generates a 0781 v2 pdf' do
        form0781_pdfs = subject
                        .new(submission.id, get_upload_location_on_instantiation: false)
                        .get_form0781_pdf
        expect(form0781_pdfs.count).to eq(1)
        expect(form0781_pdfs.first[:type]).to eq('21-0781V2')
      end
    end
  end
end
