# frozen_string_literal: true
require 'rails_helper'
require 'facilities/bulk_client'

describe Facilities::BulkClient do
  let(:conn) { instance_double('Faraday::Connection') }
  let(:count_args) { { where: '1=1', returnCountOnly: true, f: 'json' } }
  subject { described_class.new('http://www.example.com') }

  before(:each) do
    subject.instance_variable_set(:@conn, conn)
  end

  describe '.last_edit_date' do
    context 'with a timeout' do
      it 'should return nil' do
        allow(conn).to receive(:get).and_raise(Faraday::TimeoutError)
        response = subject.last_edit_date
        expect(response).to be_nil
      end
    end

    context 'with a connection error' do
      it 'should return nil' do
        allow(conn).to receive(:get).with('', f: 'json').and_raise(Faraday::ConnectionFailed.new(nil))
        result = subject.last_edit_date
        expect(result).to be_nil
      end
    end

    context 'with a service error' do
      it 'should return nil' do
        allow(conn).to receive(:get).with('', f: 'json')
          .and_raise(Facilities::Errors::RequestError.new('Error response', 400))
        result = subject.last_edit_date
        expect(result).to be_nil
      end
    end
  end

  describe '.fetch_all' do
    context 'with a timeout' do
      it 'should raise error' do
        allow(conn).to receive(:get).and_raise(Faraday::TimeoutError)
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end

    context 'with a connection error' do
      it 'should raise error' do
        allow(conn).to receive(:get).and_raise(Faraday::ConnectionFailed.new(nil))
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end

    context 'with a service error' do
      it 'should raise error' do
        allow(conn).to receive(:get).and_raise(Facilities::Errors::RequestError.new('Error response', 400))
        expect { subject.fetch_all }.to raise_error(Facilities::Errors::ServiceError)
      end
    end
  end
end
