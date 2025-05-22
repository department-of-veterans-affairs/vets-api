# frozen_string_literal: true

require 'rails_helper'
require 'csv'
require 'va_profile/service'

describe VAProfile::Service do
  subject       { described_class.new(user) }

  let(:user)    { build(:user, :loa3) }
  let(:status)  { 400 }
  let(:message) { 'the server responded with status 400' }
  let(:file)    { Rails.root.join('spec', 'support', 'va_profile', 'api_response_error_messages.csv') }

  describe '#handle_error' do
    before do
      allow_any_instance_of(Common::Client::Base).to receive_message_chain(:config, :base_path) { '' }
    end

    context 'when given a Common::Client::Errors::ClientError from a VAProfile service call' do
      it 'maps the VAProfile error code to the appropriate vets-api error message', :aggregate_failures do
        CSV.foreach(file, headers: true) do |row|
          row   = strip_row_headers(row)
          error = Common::Client::Errors::ClientError.new(message, status, body_for(row))
          code  = row['Message Code']&.strip

          next if code.blank?

          expect { subject.send('handle_error', error) }.to raise_error do |e|
            Rails.logger.debug { "Failing code: #{code}" } if e.errors.first.code != "VET360_#{code}"

            expect(e.errors.first.code).to eq("VET360_#{code}")
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end

    context 'when given a Common::Client::Errors::ParsingError from a VAProfile service call' do
      let(:error) { Common::Client::Errors::ParsingError.new }

      it 'logs an error message to sentry', :aggregate_failures do
        expect(Sentry).to receive(:set_extras)

        expect { subject.send('handle_error', error) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
        end
      end

      it 'raises a VET360_502 backend exception', :aggregate_failures do
        expect { subject.send('handle_error', error) }.to raise_error do |e|
          expect(e.errors.first.code).to eq('VET360_502')
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'when error.body is not a Hash' do
      it 'raises a VET360_502', :aggregate_failures do
        invalid_body = '<html>Some response body</html>'
        error        = Common::Client::Errors::ClientError.new('some message', 502, invalid_body)

        expect { subject.send('handle_error', error) }.to raise_error do |e|
          expect(e.errors.first.code).to eq('VET360_502')
          expect(e.original_body).to eq(invalid_body)
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#log_dates' do
    it 'logs dates in the request' do
      expect(Sentry).to receive(:set_extras).with(
        request_dates: {
          'effectiveStartDate' => '2018-06-06T15:35:55.000Z',
          'effectiveEndDate' => nil, 'sourceDate' => '2018-06-06T15:35:55.000Z'
        }
      )

      subject.send(
        :log_dates,
        { 'bio' =>
          { 'addressId' => 42,
            'addressLine1' => '1493 Martin Luther King Rd',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPOU' => 'RESIDENCE/CHOICE',
            'addressType' => 'DOMESTIC',
            'cityName' => 'Fulton',
            'countryCodeISO2' => nil,
            'countryCodeISO3' => 'USA',
            'countryName' => 'USA',
            'county' => { 'countyCode' => nil, 'countyName' => nil },
            'intPostalCode' => nil,
            'provinceName' => nil,
            'stateCode' => 'MS',
            'zipCode5' => '38843',
            'zipCode4' => nil,
            'originatingSourceSystem' => 'VETSGOV',
            'sourceSystemUser' => '1234',
            'sourceDate' => '2018-06-06T15:35:55.000Z',
            'vet360Id' => '123456789',
            'effectiveStartDate' => '2018-06-06T15:35:55.000Z',
            'effectiveEndDate' => nil } }.to_json
      )
    end
  end

  describe '#raise_backend_exception' do
    context 'regarding its reporting' do
      it 'increments the StatsD error counter', :aggregate_failures do
        error_key = 'VET360_ADDR133'

        expect(VAProfile::Stats).to receive(:increment_exception).with(error_key)
        expect { subject.send('raise_backend_exception', error_key, 'test') }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end
  end

  describe '#raise_invalid_body' do
    context 'regarding its reporting' do
      it 'increments the StatsD error counter', :aggregate_failures do
        error_key = 'VET360_502'

        expect(VAProfile::Stats).to receive(:increment_exception).with(error_key)
        expect { subject.send('raise_invalid_body', nil, 'test') }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end
  end

  describe '#perform' do
    context 'regarding its reporting' do
      before do
        allow_any_instance_of(VAProfile::Service).to receive_message_chain(
          :config, :base_request_headers, :merge
        ) { '' }
        allow_any_instance_of(Common::Client::Base).to receive(:perform).and_return(nil)
      end

      it 'increments the StatsD VAProfile total_operations counter' do
        expect { subject.perform(:get, 'some_path') }.to trigger_statsd_increment(
          "#{VAProfile::Service::STATSD_KEY_PREFIX}.total_operations"
        )
      end
    end
  end
end

def body_for(row)
  {
    'messages' => [
      {
        'code' => row['Message Code']&.to_s&.strip,
        'key' => row['Message Key']&.to_s&.strip,
        'severity' => 'ERROR',
        'text' => row['Message Description']&.to_s&.strip
      }
    ],
    'tx_audit_id' => '3773cd41-0958-4bbe-a035-16ae353cde03',
    'status' => 'REJECTED'
  }
end

def strip_row_headers(row)
  row.to_hash.transform_keys(&:strip)
end
