# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Base do
  module Specs
    module Common
      module Client
        class TestConfiguration < DefaultConfiguration
          def adapter_only
            true
          end
        end

        class TestService < ::Common::Client::Base
          configuration TestConfiguration
        end
      end
    end
  end

  describe '#request' do
    it 'raises security error when http client is used without stripping cookies' do
      expect { Specs::Common::Client::TestService.new.send(:request, :get, '', nil) }.to raise_error(
        Common::Client::SecurityError
      )
    end
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'permanentlies set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'permanentlies set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'returns an empty hash' do
        empty_hash = {}

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end

  describe '#response_hash_from_error' do
    subject { Common::Client::Base.new.send(:response_hash_from_error, error) }

    context 'objects without .response' do
      let(:empty_return) { { response: { hash: nil, object: nil } } }

      context 'error is nil' do
        let(:error) { nil }

        it { is_expected.to eq(empty_return) }
      end

      context 'error is 55' do
        let(:error) { 55 }

        it { is_expected.to eq(empty_return) }
      end
    end

    context 'objects with .response' do
      let(:class_with_response) { Struct.new(:response) }

      context 'response has .to_hash' do
        let(:hash) { 99 }
        let(:error) { class_with_response.new(Struct.new(:to_hash).new(hash)) }

        it { is_expected.to eq(response: { hash: hash, object: error.response }) }
      end

      context 'response has .status, .body, .headers' do
        let(:status) { 600 }
        let(:body) { 'body' }
        let(:headers) { 'headers' }
        let(:error) do
          class_with_response.new(
            Struct.new(:status, :body, :headers).new(status, body, headers)
          )
        end

        it do
          expect(subject).to eq(
            response: {
              hash: {
                status: status,
                body: body,
                headers: headers
              },
              object: error.response
            }
          )
        end
      end

      context 'response has .status, .body, but not .headers (and no .to_hash nor .to_h)' do
        let(:error) do
          class_with_response.new(
            Class.new do
              def status
                600
              end

              def body
                'body'
              end
            end.new
          )
        end

        it 'hash is nil' do
          expect(subject).to eq(
            response: {
              hash: nil,
              object: error.response
            }
          )
        end
      end

      context 'response has .to_hash, .status, .body, and .headers' do
        let(:to_hash) { 'cat' }
        let(:status) { 600 }
        let(:body) { 'body' }
        let(:headers) { 'headers' }
        let(:error) do
          class_with_response.new(
            Struct.new(:to_hash, :status, :body, :headers).new(to_hash, status, body, headers)
          )
        end

        it 'uses .to_hash over .status, .body, .headers' do
          expect(subject).to eq(
            response: {
              hash: to_hash,
              object: error.response
            }
          )
        end
      end

      context 'response IS a Hash' do
        let(:hash) { { a: 1, b: 2, c: 3 } }
        let(:error) { class_with_response.new(hash) }

        it do
          expect(subject).to eq(
            response: {
              hash: hash,
              object: error.response
            }
          )
        end
      end

      context 'response has none of the methods we\'re looking for, and is not a Hash' do
        let(:response) { 88 }
        let(:error) { class_with_response.new(response) }

        it do
          expect(subject).to eq(
            response: {
              hash: nil,
              object: error.response
            }
          )
        end
      end
    end
  end

  describe '#response_status_from_error' do
    subject { Common::Client::Base.new.send(:response_status_from_error, error) }

    context 'objects without .response' do
      context 'error is nil' do
        let(:error) { nil }

        it { is_expected.to eq(nil) }
      end

      context 'error is 55' do
        let(:error) { 55 }

        it { is_expected.to eq(nil) }
      end
    end

    context 'objects with .response' do
      let(:class_with_response) { Struct.new(:response) }

      context 'response has .to_hash' do
        let(:error) { class_with_response.new(Struct.new(:to_hash).new(hash)) }

        describe '.to_hash does not return a hash' do
          let(:hash) { 99 }

          it { is_expected.to eq(nil) }
        end

        describe '.to_hash returns hash with :status field' do
          let(:status) { 600 }
          let(:hash) { { status: status } }

          it { is_expected.to eq(status) }
        end

        describe '.to_hash returns hash without :status field' do
          let(:hash) { { b: 2 } }

          it { is_expected.to eq(nil) }
        end
      end

      context 'response has .status, .body, .headers' do
        let(:status) { 900 }
        let(:error) do
          class_with_response.new(
            Struct.new(:status, :body, :headers).new(status, 'body', 'headers')
          )
        end

        it { is_expected.to eq(status) }
      end

      context 'response has .status, .body, but not .headers' do
        let(:status) { 900 }
        let(:error) do
          class_with_response.new(
            Struct.new(:status, :body, :to_h).new(status, 'body', nil)
          )
        end

        it { is_expected.to eq(nil) }
      end

      context 'response has .to_hash, .status, .body, and .headers' do
        let(:status) { 'dog' }
        let(:to_hash) { { status: status } }
        let(:error) do
          class_with_response.new(
            Struct.new(:to_hash, :status, :body, :headers).new(to_hash, 'a', 'b', 'c')
          )
        end

        it('uses .to_hash over .status') { is_expected.to eq(status) }
      end

      context 'response IS a Hash' do
        let(:status) { 'banana' }
        let(:error) { class_with_response.new(status: status) }

        it { is_expected.to eq(status) }
      end

      context 'response has none of the methods we\'re looking for, and is not a Hash' do
        let(:response) { 88 }
        let(:error) { class_with_response.new(response) }

        it { is_expected.to eq(nil) }
      end
    end
  end

  describe '#response_body_from_error' do
    subject { Common::Client::Base.new.send(:response_body_from_error, error) }

    context 'objects without .response' do
      context 'error is nil' do
        let(:error) { nil }

        it { is_expected.to eq(nil) }
      end

      context 'error is 55' do
        let(:error) { 55 }

        it { is_expected.to eq(nil) }
      end
    end

    context 'objects with .response' do
      let(:class_with_response) { Struct.new(:response) }

      context 'response has .to_hash' do
        let(:error) { class_with_response.new(Struct.new(:to_hash).new(hash)) }

        describe '.to_hash does not return a hash' do
          let(:hash) { 99 }

          it { is_expected.to eq(nil) }
        end

        describe '.to_hash returns hash with :body field' do
          let(:body) { 'squirrel' }
          let(:hash) { { body: body } }

          it { is_expected.to eq(body) }
        end

        describe '.to_hash returns hash without :body field' do
          let(:hash) { { b: 2 } }

          it { is_expected.to eq(nil) }
        end
      end

      context 'response has .status, .body, .headers' do
        let(:body) { 'tiger' }
        let(:error) do
          class_with_response.new(
            Struct.new(:status, :body, :headers).new('status', body, 'headers')
          )
        end

        it { is_expected.to eq(body) }
      end

      context 'response has .status, .body, but not .headers' do
        let(:body) { 'lion' }
        let(:error) do
          class_with_response.new(
            Struct.new(:status, :body, :to_h).new('status', body, nil)
          )
        end

        it { is_expected.to eq(nil) }
      end

      context 'response has .to_hash, .status, .body, and .headers' do
        let(:body) { 'zebra' }
        let(:to_hash) { { body: body } }
        let(:error) do
          class_with_response.new(
            Struct.new(:to_hash, :status, :body, :headers).new(to_hash, 'a', 'b', 'c')
          )
        end

        it('uses .to_hash over .body') { is_expected.to eq(body) }
      end

      context 'response IS a Hash' do
        let(:body) { 'banana' }
        let(:error) { class_with_response.new(body: body) }

        it { is_expected.to eq(body) }
      end

      context 'response has none of the methods we\'re looking for, and is not a Hash' do
        let(:response) { 88 }
        let(:error) { class_with_response.new(response) }

        it { is_expected.to eq(nil) }
      end
    end
  end
end
