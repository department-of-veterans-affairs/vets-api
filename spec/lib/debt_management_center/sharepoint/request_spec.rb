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
    let(:form_submission) { create(:form5655_submission) }
    let(:station_id) { '123' }
    let(:file_path) { ::Rails.root.join(*'/spec/fixtures/dmc/5655.pdf'.split('/')).to_s }
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
    end

    it 'uploads a pdf file to SharePoint' do
      VCR.use_cassette('vha/sharepoint/upload_pdf') do
        response = subject.upload(form_contents: form_content, form_submission:, station_id:)
        expect(response.success?).to be(true)
      end
    end
  end
end
