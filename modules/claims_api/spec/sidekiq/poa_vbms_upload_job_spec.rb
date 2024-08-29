# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/fake_vbms'

RSpec.describe ClaimsApi::PoaVBMSUploadJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    @vbms_client = FakeVBMS.new
    allow(VBMS::Client).to receive(:from_env_vars).and_return(@vbms_client)
    allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return false
    # allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return false
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  describe 'uploading a file to BD' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    it 'updates the power of attorney record and updates the POA code in BGDS when there\'s a successful response' do
      document_response = OpenStruct.new(upload_document_response: {
        '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
        '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
      }.with_indifferent_access)
      allow_any_instance_of(BGS::PersonWebService)
        .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
      allow_any_instance_of(ClaimsApi::PoaVBMSUploadJob).to receive(:fetch_file_path).and_return('/tmp/path.pdf')

      allow_any_instance_of(ClaimsApi::BD).to receive(:upload).and_return(document_response)
      VCR.use_cassette('claims_api/bd/upload') do
        expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload

        expect(power_of_attorney.status).to eq('submitted')
      end
    end

    it 'rescues file not found from S3, updates POA record, and re-raises to allow Sidekiq retries' do
      VCR.use_cassette('claims_api/bd/upload') do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::BD).to receive(:upload).and_raise(Errno::ENOENT)
        expect { subject.new.perform(power_of_attorney.id) }.to raise_error(Errno::ENOENT)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('errored')
      end
    end

    it "rescues 'VBMS::FilenumberDoesNotExist' error, updates record, and re-raises exception" do
      VCR.use_cassette('claims_api/bd/upload') do
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::BD).to receive(:upload)
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
      VCR.use_cassette('claims_api/bd/upload') do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        response = OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::BD).to receive(:upload).and_return(response)
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('submitted')
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

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      poa = create_poa
      error_msg = 'An error occurred for the POA VBMS Upload Job'
      msg = { 'args' => [poa.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: poa.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end

  describe 'benefits documents upload feature flag' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    it 'calls the benefits document API with doc_type L075' do
      VCR.use_cassette('claims_api/bd/upload') do
        expect_any_instance_of(ClaimsApi::BD).to receive(:upload).with(
          claim: power_of_attorney,
          pdf_path: anything,
          doc_type: 'L075'
        )
        subject.new.perform(power_of_attorney.id)
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
