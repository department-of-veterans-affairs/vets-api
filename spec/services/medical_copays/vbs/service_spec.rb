# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::Service do
  subject { described_class.build(user: user) }

  let(:user) do
    build(:user, :loa3,
          vha_facility_ids: %w[757 358],
          vha_facility_hash: { '757' => %w[36546], '358' => %w[36546] })
  end
  let(:today_date) { Time.zone.today.strftime('%m%d%Y') }

  describe 'attributes' do
    it 'responds to request' do
      expect(subject.respond_to?(:request)).to be(true)
    end

    it 'responds to request_data' do
      expect(subject.respond_to?(:request_data)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject).to be_an_instance_of(MedicalCopays::VBS::Service)
    end
  end

  describe '#get_copays' do
    it 'raises a custom error when request data is invalid' do
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

      expect { subject.get_copays }.to raise_error(MedicalCopays::VBS::InvalidVBSRequestError)
        .and trigger_statsd_increment('api.mcp.vbs.failure')
    end

    it 'returns a response hash' do
      url = '/base/path/GetStatementsByEDIPIAndVistaAccountNumber'
      data = { edipi: '123456789', vistaAccountNumbers: [36_546] }
      response = Faraday::Response.new(status: 200, body:
        [
          {
            'foo_bar' => 'bar',
            'pS_STATEMENT_DATE' => today_date
          }
        ])

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:to_hash).and_return(data)
      allow_any_instance_of(MedicalCopays::Request).to receive(:post).with(url, data).and_return(response)

      VCR.use_cassette('user/get_facilities_empty', match_requests_on: %i[method uri]) do
        expect(subject.get_copays).to eq({ status: 200, data:
          [
            {
              'fooBar' => 'bar',
              'pSStatementDate' => today_date
            }
          ] })
      end
    end

    it 'includes zero balance statements if available' do
      url = '/base/path/GetStatementsByEDIPIAndVistaAccountNumber'
      data = { edipi: '123456789', vistaAccountNumbers: [36_546] }
      response = Faraday::Response.new(status: 200, body:
        [
          {
            'foo_bar' => 'bar',
            'pS_STATEMENT_DATE' => today_date
          }
        ])
      zero_balance_response = [{ 'bar_baz' => 'baz', 'pS_STATEMENT_DATE' => today_date }]

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:to_hash).and_return(data)
      allow_any_instance_of(MedicalCopays::Request).to receive(:post).with(url, data).and_return(response)
      allow_any_instance_of(MedicalCopays::ZeroBalanceStatements).to receive(:list).and_return(zero_balance_response)

      VCR.use_cassette('user/get_facilities_empty', match_requests_on: %i[method uri]) do
        expect(subject.get_copays).to eq({ status: 200, data:
        [
          {
            'fooBar' => 'bar',
            'pSStatementDate' => today_date
          },
          {
            'barBaz' => 'baz',
            'pSStatementDate' => today_date
          }
        ] })
      end
    end
  end

  describe '#get_pdf_statement_by_id' do
    statement_id = '123456789'
    it 'raises an error when request data is invalid' do
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

      expect do
        subject.get_pdf_statement_by_id(statement_id)
      end.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
    end

    it 'returns a response hash' do
      url = "/base/path/GetPDFStatementById/#{statement_id}"
      response = Faraday::Response.new(body: { 'statement' => Base64.encode64('foo bar') }, status: 200)

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::Request).to receive(:get).with(url).and_return(response)

      expect(subject.get_pdf_statement_by_id(statement_id)).to eq('foo bar')
    end
  end
end
