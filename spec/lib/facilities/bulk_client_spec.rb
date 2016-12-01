# frozen_string_literal: true
require 'rails_helper'
require 'facilities/bulk_client'

describe Facilities::BulkClient do
  let(:conn) { instance_double('Faraday::Connection') }
  let(:count_args) { { where: '1=1', returnCountOnly: true, f: 'json' } }
  let(:conn_failed) { Faraday::ConnectionFailed.new(nil) }
  let(:err_response) { Facilities::Errors::RequestError.new('Error response', 400) }
  subject { described_class.new('http://www.example.com') }

  describe '.last_edit_date' do
    context 'with a timeout' do
      it 'should return nil' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        response = subject.last_edit_date
        expect(response).to be_nil
      end
    end

    context 'with a connection error' do
      it 'should return nil' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('', f: 'json').and_raise(conn_failed)
        result = subject.last_edit_date
        expect(result).to be_nil
      end
    end

    context 'with a service error' do
      it 'should return nil' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('', f: 'json').and_raise(err_response)
        result = subject.last_edit_date
        expect(result).to be_nil
      end
    end
  end

  describe '.fetch_all' do
    context 'with a timeout' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end

    context 'with a connection error' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(conn_failed)
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end

    context 'with a service error' do
      it 'should raise error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(err_response)
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end
  end
end
