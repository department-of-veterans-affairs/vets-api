# frozen_string_literal: true

require 'rails_helper'

require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission
require 'sidekiq/form526_backup_submission_process/submit'

RSpec.describe Sidekiq::Form526BackupSubmissionProcess::Processor do
  subject { described_class }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
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
        allow(Time).to receive(:now).and_return(Time.zone.at(mock_timestamp))
        upload_data.each do |ud|
          filename = ud['name']
          # Use the actual fixture filename that exists, not the name from upload data
          # The fixture file has the full long name
          actual_fixture_filename = if filename.include?('medical-records-long-name')
                                      'medical-records-long-name-rt36FSVxn2VTCGJye9i2UTBjy' \
                                        'ZnYuhXR0uXTFcQzX7eE61r4PUuobiS2V958VHS9r2999H37jJVbY' \
                                        '020p5AR2UQS6S8nZNLXCw9s5hC94m1Z0zdsxlDDDjwJ9o3Fhqky6' \
                                        'lLEnKNmBPyaHda71xPN0N7gy7ux9Yu187I.pdf'
                                    else
                                      filename
                                    end
          file_path = Rails.root.join('spec', 'fixtures', 'files', actual_fixture_filename)
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
              # The processor creates paths with format: random_path.timestamp.filename
              expected_base_path = "#{mock_random_file_path}.#{mock_timestamp}"
              processed_files.each do |processed_file|
                if processed_file['name'].length > 101
                  # For long filenames, test that the processor handles them without filesystem errors
                  original_filename = processed_file['name']
                  actual_path = processed_file[:file]

                  # Basic structure assertions
                  expect(actual_path).to match(%r{^tmp/.+\d+\..+\.pdf$})
                  expect(actual_path).to include(mock_timestamp.to_s)

                  # Original filename should be longer than limit
                  expect(original_filename.length).to be > SupportingEvidenceAttachmentUploader::MAX_FILENAME_LENGTH

                  # Extension preservation
                  expect(actual_path).to end_with('.pdf')
                  expect(original_filename).to end_with('.pdf')

                  # Most importantly: the file should be successfully created despite long filename
                  # This validates that our filename shortening prevents filesystem errors
                  expect(File).to exist(actual_path)

                  # The processor should attempt to use shortened filename logic
                  # (even if the model doesn't provide a shortened name in this test context)
                  expect(actual_path.length).to be > expected_base_path.length

                else
                  # For short filenames, the path should be: {random_path}.{timestamp}.{original_name}
                  expected_path = "#{expected_base_path}.#{processed_file['name']}"
                  expect(processed_file[:file].length).to eq(expected_path.length)
                  expect(processed_file[:file]).to eq(expected_path)
                end

                # General assertions for all files
                expect(processed_file[:file]).to match(%r{^tmp/[a-zA-Z0-9_\-.]+\.pdf$})
                expect(File).to exist(processed_file[:file])
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
