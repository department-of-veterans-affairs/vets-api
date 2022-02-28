# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/fake_vbms'

RSpec.describe ClaimsApi::VBMSUploadJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
    @vbms_client = FakeVBMS.new
    allow(VBMS::Client).to receive(:from_env_vars).and_return(@vbms_client)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  describe 'uploading a file to vbms' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    it 'responds properly when there is a 500 error' do
      VCR.use_cassette('vbms/document_upload_500') do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })

        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.vbms_upload_failure_count).to eq(1)
      end
    end

    it 'creates a second job if there is a failure' do
      VCR.use_cassette('vbms/document_upload_500') do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect(ClaimsApi::PoaUpdater).not_to receive(:perform_async)
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(1)
      end
    end

    it 'does not create an new job if had 5 failures' do
      VCR.use_cassette('vbms/document_upload_500') do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect(ClaimsApi::PoaUpdater).not_to receive(:perform_async)

        power_of_attorney.update(vbms_upload_failure_count: 4)
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(0)
      end
    end

    it 'updates the power of attorney record and updates the POA code in BGDS when there\'s a successful response' do
      token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
      document_response = OpenStruct.new(upload_document_response: {
        '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
        '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
      }.with_indifferent_access)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
      allow_any_instance_of(ClaimsApi::VBMSUploadJob).to receive(:fetch_file_path).and_return('/tmp/path.pdf')

      allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
      allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload_document).and_return(document_response)
      VCR.use_cassette('vbms/document_upload_success') do
        expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload

        expect(power_of_attorney.status).to eq('uploaded')
        expect(power_of_attorney.vbms_document_series_ref_id).to eq('{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}')
        expect(power_of_attorney.vbms_new_document_version_ref_id).to eq('{52300B69-1D6E-43B2-8BEB-67A7C55346A2}')
      end
    end

    it 'rescues file not found from S3, updates POA record, and re-raises to allow Sidekiq retries' do
      VCR.use_cassette('vbms/document_upload_success') do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload_document).and_raise(Errno::ENOENT)
        expect { subject.new.perform(power_of_attorney.id) }.to raise_error(Errno::ENOENT)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('errored')
      end
    end

    it "rescues 'VBMS::FilenumberDoesNotExist' error, updates record, and re-raises exception" do
      VCR.use_cassette('vbms/document_upload_success') do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token)
          .and_raise(VBMS::FilenumberDoesNotExist.new(500, 'HelloWorld'))

        expect { subject.new.perform(power_of_attorney.id) }.to raise_error(VBMS::FilenumberDoesNotExist)
        power_of_attorney.reload

        expect(power_of_attorney.status).to eq('errored')
        expect(power_of_attorney.vbms_error_message).to eq(
          'VBMS is unable to locate file number'
        )
      end
    end

    it 'uploads to VBMS' do
      VCR.use_cassette('vbms/document_upload_success') do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        response = OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
        allow_any_instance_of(VBMS::Client).to receive(:send_request).and_return(response)
        allow(VBMS::Requests::UploadDocument).to receive(:new).and_return({})
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('uploaded')
      end
    end
  end

  describe '#stream_to_temp_file' do
    it 'converts a stream to a temp file' do
      expect(described_class.new.stream_to_temp_file(StringIO.new)).to be_a Tempfile
    end
  end

  describe '#fetch_file_path' do
    subject { described_class.new.fetch_file_path(fake_uploader) }

    let(:fake_uploader) do
      OpenStruct.new file: OpenStruct.new(url: nil, file: fake_uploader_path)
    end
    let(:fake_uploader_path) { Object.new }

    context 'uploads disabled' do
      with_settings(Settings.evss.s3, uploads_enabled: false) do
        it 'returns uploaders file path' do
          expect(subject).to be fake_uploader_path
        end
      end
    end

    context 'uploads enabled' do
      context 'OpenURI returns a StringIO' do
        it 'returns a path' do
          with_settings(Settings.evss.s3, uploads_enabled: true) do
            allow(URI).to receive(:parse).and_return(OpenStruct.new(open: StringIO.new))
            expect(subject).to be_a String
            expect(subject).not_to be_empty
          end
        end
      end

      context 'OpenURI returns a Tempfile' do
        it 'returns a path' do
          with_settings(Settings.evss.s3, 'uploads_enabled' => true) do
            allow(URI).to receive(:parse).and_return(OpenStruct.new(open: Tempfile.new))
            expect(subject).to be_a String
            expect(subject).not_to be_empty
          end
        end
      end
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end
end
