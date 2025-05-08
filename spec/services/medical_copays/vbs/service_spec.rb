# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::Service do
  subject { described_class.build(user:) }

  def stub_get_copays(response)
    allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(response)
  end

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
    before do
      allow(Flipper).to receive(:enabled?).with(:medical_copays_api_key_change).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:medical_copays_zero_debt).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:medical_copays_six_mo_window).and_return(false)
    end

    context 'with a cached response' do
      it 'logs that a cached response was returned' do
        allow_any_instance_of(MedicalCopays::VBS::Service)
          .to receive(:get_user_cached_response)
                .and_return(Faraday::Response.new(status: 200, body: []))

        expect { subject.get_copays }
          .to trigger_statsd_increment('api.mcp.vbs.init_cached_copays.fired')
                .and trigger_statsd_increment('api.mcp.vbs.init_cached_copays.cached_response_returned')
      end
    end

    context 'with an empty copay response' do
      it 'logs that an empty response was cached' do
        empty_response = Faraday::Response.new(status: 200, body: [])
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_response).and_return(empty_response)

        expect { subject.get_copays }
          .to trigger_statsd_increment('api.mcp.vbs.init_cached_copays.fired')
                .and trigger_statsd_increment('api.mcp.vbs.init_cached_copays.empty_response_cached')
      end
    end

    it 'raises a custom error when request data is invalid' do
      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

      expect { subject.get_copays }.to raise_error(MedicalCopays::VBS::InvalidVBSRequestError)
                                         .and trigger_statsd_increment('api.mcp.vbs.failure')
    end

    it 'returns a response hash' do
      url = '/vbsapi/GetStatementsByEDIPIAndVistaAccountNumber'
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
      url = '/vbsapi/GetStatementsByEDIPIAndVistaAccountNumber'
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

    context 'with debts_copay_logging flipper enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_copay_logging).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:medical_copays_api_key_change).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:medical_copays_zero_debt).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:medical_copays_six_mo_window).and_return(true)
      end

      it 'logs that a response was cached' do
        allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
        allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:to_hash).and_return(
          { edipi: '123456789', vistaAccountNumbers: [36_546] }
        )
        allow_any_instance_of(MedicalCopays::Request).to receive(:post)
                                                           .and_return(Faraday::Response.new(status: 200, body: []))

        expect(Rails.logger).to receive(:info).with(
          a_string_including('MedicalCopays::VBS::Service#get_copay_response request data: ')
        )
        VCR.use_cassette('user/get_facilities_empty', match_requests_on: %i[method uri]) do
          subject.get_copays
        end
      end
    end
  end

  describe '#get_copay_by_id' do
    it 'filters multiple statements to return a single one' do
      response = {
        status: 200,
        data: [
          {
            'id' => '2f1569ff-64cf-4300-8dd1-5ec3caded615',
            'pSStatementDate' => today_date
          },
          {
            'id' => 'b9cdcc61-2e5a-47c3-b314-4449606e65c7',
            'pSStatementDate' => today_date
          }
        ]
      }

      stub_get_copays(response)

      expect(subject.get_copay_by_id('b9cdcc61-2e5a-47c3-b314-4449606e65c7')).to eq({ status: 200, data:
      {
        'id' => 'b9cdcc61-2e5a-47c3-b314-4449606e65c7',
        'pSStatementDate' => today_date
      } })
    end

    it 'return error message when service error' do
      response = { data: { message: 'Bad request' }, status: 400 }
      stub_get_copays(response)

      expect(subject.get_copay_by_id('b9cdcc61-2e5a-47c3-b314-4449606e65c7')).to eq(response)
    end

    it 'raises an error if no statement with that id' do
      stub_get_copays({ status: 200, data: [] })

      expect { subject.get_copay_by_id('b9cdcc61-2e5a-47c3-b314-4449606e65c7') }.to raise_error(
        MedicalCopays::VBS::Service::StatementNotFound
      )
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
      url = "/vbsapi/GetPDFStatementById/#{statement_id}"
      response = Faraday::Response.new(response_body: { 'statement' => Base64.encode64('foo bar') }, status: 200)

      allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(true)
      allow_any_instance_of(MedicalCopays::Request).to receive(:get).with(url).and_return(response)

      expect(subject.get_pdf_statement_by_id(statement_id)).to eq('foo bar')
    end
  end
end
