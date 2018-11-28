# frozen_string_literal: true

require 'rails_helper'
describe Common::Client::FaradayMiddlewareCheck do
  let(:service) do
    Class.new do
      include Common::Client::FaradayMiddlewareCheck
      def connection
        Faraday.new('http://example.com') do |faraday|
          faraday.adapter :httpclient
        end
      end

      def conn
        faraday_config_check(connection.builder.handlers)
        connection
      end
    end.new
  end

  describe '#check_for_remove_cookies' do
    context 'enforces Faraday middleware requirements' do
      it 'requires cookies be stripped for http client' do
        expect { service.conn }.to raise_error(Common::Client::SecurityError, 'http client needs cookies stripped')
      end
    end
  end
  describe 'check_for_breakers_and_rescue_timeout_placement' do
    context 'with `breakers`' do
      context 'not in the first position' do
        it 'raises an error' do
          allow(service).to receive(:connection).and_return(
            Faraday.new('http://example.com') do |faraday|
              faraday.request :soap_headers
              faraday.use :breakers
            end
          )
          expect { service.conn }.to raise_error(
            Common::Client::BreakersImplementationError, 'Breakers should be the first middleware implemented.'
          )
        end
      end
      context 'in the first position' do
        it 'returns a Faraday::Connection' do
          allow(service).to receive(:connection).and_return(
            Faraday.new('http://example.com') do |faraday|
              faraday.use :breakers
              faraday.request :soap_headers
            end
          )
          expect(service.conn).to be_a(Faraday::Connection)
        end
      end
      context 'and `log_timeout_as_warning`' do
        context 'with `log_timeout_as_warning` in first position, `breakers` in second' do
          it 'returns a Faraday::Connection' do
            allow(service).to receive(:connection).and_return(
              Faraday.new('http://example.com') do |faraday|
                faraday.request :log_timeout_as_warning
                faraday.use :breakers
                faraday.request :soap_headers
              end
            )
            expect(service.conn).to be_a(Faraday::Connection)
          end
        end
        context 'without `log_timeout_as_warning` in first position, `breakers` in second' do
          it 'raises an error' do
            allow(service).to receive(:connection).and_return(
              Faraday.new('http://example.com') do |faraday|
                faraday.request :soap_headers
                faraday.use :breakers
                faraday.request :log_timeout_as_warning
              end
            )
            expect { service.conn }.to raise_error(
              Common::Client::BreakersImplementationError,
              ':log_timeout_as_warning should be the first middleware implemented, and Breakers should be the second.'
            )
          end
        end
      end
    end
  end
end
