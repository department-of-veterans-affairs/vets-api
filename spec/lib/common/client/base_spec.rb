# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Base do
  class Common::Client::Base::TestConfiguration < Common::Client::Configuration::REST
    def connection
      Faraday.new('http://example.com') do |faraday|
        faraday.adapter :httpclient
      end
    end

    def service_name
      'test_service'
     end
  end

  class Common::Client::Base::TestService < Common::Client::Base
    configuration Common::Client::Base::TestConfiguration
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'should permanently set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'should permanently set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'should return an empty hash' do
        empty_hash = {}

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end

  describe '#connection' do
    let(:connect) { Common::Client::Base::TestService.new.send(:connection) }
    context 'enforces Faraday middleware requirements' do
      it 'requires cookies be stripped for http client' do
        expect { connect }.to raise_error(Common::Client::SecurityError, 'http client needs cookies stripped')
      end
      context 'with `breakers`' do
        context 'not in the first position' do
          it 'raises an error' do
            allow_any_instance_of(Common::Client::Base::TestConfiguration).to receive(:connection).and_return(
              Faraday.new('http://example.com') do |faraday|
                faraday.request :soap_headers
                faraday.use :breakers
              end
            )
            expect { connect }.to raise_error(Common::Client::BreakersImplementationError, 'Breakers should be the first middleware implemented.')
          end
        end
        context 'in the first position' do
          it 'returns a Faraday::Connection' do
            allow_any_instance_of(Common::Client::Base::TestConfiguration).to receive(:connection).and_return(
              Faraday.new('http://example.com') do |faraday|
                faraday.use :breakers
                faraday.request :soap_headers
              end
            )
            expect(connect).to be_a(Faraday::Connection)
          end
        end
        context 'and `rescue_timeout`' do
          context 'with `rescue_timeout` in first position, `breakers` in second' do
            it 'returns a Faraday::Connection' do
              allow_any_instance_of(Common::Client::Base::TestConfiguration).to receive(:connection).and_return(
                Faraday.new('http://example.com') do |faraday|
                  faraday.request :rescue_timeout
                  faraday.use :breakers
                  faraday.request :soap_headers
                end
              )
              expect(connect).to be_a(Faraday::Connection)
            end
          end
          context 'without `rescue_timeout` in first position, `breakers` in second' do
            it 'raises an error' do
              allow_any_instance_of(Common::Client::Base::TestConfiguration).to receive(:connection).and_return(
                Faraday.new('http://example.com') do |faraday|
                  faraday.request :soap_headers
                  faraday.use :breakers
                  faraday.request :rescue_timeout
                end
              )
              expect { connect }.to raise_error(Common::Client::BreakersImplementationError, ':rescue_timeout should be the first middleware implemented, and Breakers should be the second.')
            end
          end
        end
      end
    end
  end
end
