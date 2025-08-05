# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/sharepoint/request'
require 'pdf_fill/filler'

RSpec.describe DebtManagementCenter::Sharepoint::Request do
  subject do
    VCR.use_cassette('vha/sharepoint/authenticate') do
      described_class.new
    end
  end

  let(:mpi_profile) { build(:mpi_profile, family_name: 'Beer', ssn: '123456598') }
  let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

  before do
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe 'settings' do
    it 'has a sharepoint_url' do
      expect(subject.sharepoint_url).to eq('dvagov.sharepoint.com')
    end

    it 'has base_path' do
      expect(subject.base_path).to eq('/sites/vhafinance/MDW')
    end

    it 'has service_name' do
      expect(subject.service_name).to eq('VHA-SHAREPOINT')
    end

    it 'has a authentication_url' do
      expect(subject.authentication_url).to eq('https://accounts.accesscontrol.windows.net')
    end

    it 'has a client_secret' do
      expect(subject.client_secret).to eq('fake_sharepoint_client_secret')
    end

    it 'has a client_id' do
      expect(subject.client_id).to eq('fake_sharepoint_client_id')
    end

    it 'has a tenant_id' do
      expect(subject.tenant_id).to eq('fake_sharepoint_tenant_id')
    end

    it 'has a resource' do
      expect(subject.resource).to eq('00000003-0000-0ff1-ce00-000000000000')
    end
  end

  describe '.new' do
    it 'returns an instance of Uploader' do
      expect(subject).to be_an_instance_of(DebtManagementCenter::Sharepoint::Request)
    end
  end

  describe '#upload' do
    let(:form_content) { { 'foo' => 'bar' } }
    let(:form_submission) { create(:debts_api_form5655_submission) }
    let(:station_id) { '123' }
    let(:file_path) { Rails.root.join(*'/spec/fixtures/dmc/5655.pdf'.split('/')).to_s }
    let(:body) do
      {
        'd' => {
          'ID' => 1,
          'ListItemAllFields' => {
            '__deferred' => {
              'uri' => 'https://fake_url.com/base/path'
            }
          }
        }
      }
    end

    before do
      upload_time = DateTime.new(2023, 8, 29, 16, 13, 22)
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(file_path)
      allow(File).to receive(:delete).and_return(nil)
      allow(DateTime).to receive(:now).and_return(upload_time)
      allow_any_instance_of(subject.class).to receive(:set_user_data).and_return(
        {
          ssn: '123456598',
          first_name: 'xxx',
          last_name: 'Beer'
        }
      )
      allow_any_instance_of(subject.class).to receive(:access_token).and_return('fake-token')
    end

    context 'with debts_sharepoint_error_logging feature enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_sharepoint_error_logging).and_return(true)
      end

      it 'uploads a pdf file to SharePoint' do
        VCR.use_cassette('vha/sharepoint/upload_pdf', allow_playback_repeats: true) do
          response = subject.upload(form_contents: form_content, form_submission:, station_id:)
          expect(response.success?).to be(true)
        end
      end

      it 'raises a PDF error if the PDF upload fails' do
        VCR.use_cassette('vha/sharepoint/upload_pdf_400_response', allow_playback_repeats: true) do
          expect { subject.upload(form_contents: form_content, form_submission:, station_id:) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            error_details = e.errors.first
            expect(error_details.status).to eq('400')
            expect(error_details.detail).to eq('Malformed PDF request to SharePoint')
            expect(error_details.code).to eq('SHAREPOINT_PDF_400')
            expect(error_details.source).to eq('SharepointRequest')
          end
        end
      end

      it 'raises a request error if getting a list item fails' do
        VCR.use_cassette('vha/sharepoint/update_list_item_fields_400', preserve_exact_body_bytes: true,
                                                                       allow_playback_repeats: true) do
          expect { subject.upload(form_contents: form_content, form_submission:, station_id:) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            error_details = e.errors.first
            expect(error_details.status).to eq('400')
            expect(error_details.detail).to eq('Malformed request to SharePoint')
            expect(error_details.code).to eq('SHAREPOINT_400')
            expect(error_details.source).to eq('SharepointRequest')
          end
        end
      end
    end

    context 'with debts_sharepoint_error_logging feature disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_sharepoint_error_logging).and_return(false)
      end

      it 'does not log errors when submitting PDF' do
        VCR.use_cassette('vha/sharepoint/upload_pdf_400_response', allow_playback_repeats: true) do
          expect { subject.upload(form_contents: form_content, form_submission:, station_id:) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            error_details = e.errors.first
            expect(error_details.status).to eq('400')
            expect(error_details.detail).to eq('Operation failed')
            expect(error_details.code).to eq('VA900')
            expect(error_details.source).to be_nil
          end
        end
      end

      it 'does not log errors when getting a list items' do
        VCR.use_cassette('vha/sharepoint/update_list_item_fields_400', allow_playback_repeats: true,
                                                                       preserve_exact_body_bytes: true) do
          expect { subject.upload(form_contents: form_content, form_submission:, station_id:) }
            .to raise_error(Common::Exceptions::BackendServiceException) do |e|
            error_details = e.errors.first
            expect(error_details.status).to eq('400')
            expect(error_details.detail).to eq('Operation failed')
            expect(error_details.code).to eq('VA900')
            expect(error_details.source).to be_nil
          end
        end
      end

      it 'recovers from temporary failures during upload' do
        # Mock upload_pdf to fail once then succeed
        upload_attempts = 0

        success_response = instance_double(Faraday::Response,
                                           body: {
                                             'd' => {
                                               'ListItemAllFields' => {
                                                 '__deferred' => {
                                                   'uri' => 'https://fake_url.com/base/path'
                                                 }
                                               }
                                             }
                                           },
                                           success?: true)

        allow_any_instance_of(subject.class).to receive(:upload_pdf) do |_instance, **_args|
          upload_attempts += 1
          if upload_attempts == 1
            raise StandardError, 'Temporary failure'
          else
            success_response
          end
        end

        allow_any_instance_of(subject.class).to receive(:get_pdf_list_item_id).and_return(123)
        allow_any_instance_of(subject.class).to receive(:update_list_item_fields).and_return(
          instance_double(Faraday::Response, success?: true)
        )

        # Stub sleep to avoid waiting during tests
        allow(Kernel).to receive(:sleep)

        # Verify warning is logged about the retry
        expect(Rails.logger).to receive(:warn).with(/SharePoint PDF upload failed, retrying/)

        # Make the call that should trigger the retry
        response = subject.upload(form_contents: form_content, form_submission:, station_id:)

        # Verify it attempted multiple times
        expect(upload_attempts).to eq(2)
        expect(response.success?).to be(true)
      end
    end
  end
end
