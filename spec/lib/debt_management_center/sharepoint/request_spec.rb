# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/sharepoint/request'

RSpec.describe DebtManagementCenter::Sharepoint::Request do
  subject { described_class.new }

  def mock_faraday
    client_stub = instance_double('Faraday::Connection')
    faraday_response = instance_double('Faraday::Response')
    allow(Faraday).to receive(:new).and_return(client_stub)
    allow(client_stub).to receive(:post).and_return(faraday_response)
    allow(client_stub).to receive(:get).and_return(faraday_response)
    allow(faraday_response).to receive(:body).and_return(body)
    allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(file_path)

    client_stub
  end

  before do
    allow_any_instance_of(DebtManagementCenter::Sharepoint::Request)
      .to receive(:set_sharepoint_access_token)
      .and_return('123abc')
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe 'settings' do
    it 'has a sharepoint_url' do
      expect(subject.sharepoint_url).to eq('fake_url.com')
    end

    it 'has base_path' do
      expect(subject.base_path).to eq('/base')
    end

    it 'has service_name' do
      expect(subject.service_name).to eq('VHA-SHAREPOINT')
    end

    it 'has a authentication_url' do
      expect(subject.authentication_url).to eq('https://fake_auth_url.com')
    end

    it 'has a client_secret' do
      expect(subject.client_secret).to eq('xxxxxxxxx')
    end

    it 'has a client_id' do
      expect(subject.client_id).to eq('51dadf135qwwc')
    end

    it 'has a tenant_id' do
      expect(subject.tenant_id).to eq('ad21angkl35dadf43ad56')
    end

    it 'has a resource' do
      expect(subject.resource).to eq('23asdb54ada655a3')
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

    it 'uploads a pdf file to SharePoint' do
      client_stub = mock_faraday
      expect(client_stub).to receive(:post).twice
      expect(client_stub).to receive(:get).once

      subject.upload(form_contents: form_content, form_submission:, station_id:)
    end
  end
end
