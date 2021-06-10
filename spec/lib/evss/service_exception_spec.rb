# frozen_string_literal: true

require 'rails_helper'

describe EVSS::ServiceException do
  describe '.key' do
    context 'when ERROR_MAP has a default' do
      before do
        error_map = {
          b: 'evss.b',
          a: 'evss.a',
          d: 'common.exceptions.internal_server_error',
          c: 'evss.c',
          default: 'default'
        }

        stub_const 'EVSS::ServiceException::ERROR_MAP', error_map
      end

      it 'ignores EVSS error message order, when there are multiple EVSS error messsages,' \
         ' and uses the order of ERROR_MAP to choose which is the highest priority error' do
        original_body = {
          messages: [
            { key: 'a' },
            { key: 'b' },
            { key: 'c' }
          ]
        }.as_json
        expect(described_class.new(original_body).key).to be 'evss.b'
      end

      it 'ignores EVSS error message severity' do
        original_body = {
          messages: [
            { key: 'a', severity: 'FATAL' },
            { key: 'c', severity: 'ERROR' },
            { key: 'b', severity: 'INFO' }
          ]
        }.as_json
        expect(described_class.new(original_body).key).to be 'evss.b'
      end

      it "uses ERROR_MAP's default when error keys aren't recognized" do
        original_body = { messages: [{ key: 'x', severity: 'FATAL' }] }.as_json
        expect(described_class.new(original_body).key).to be 'default'
      end
    end

    context "when ERROR_MAP doesn't specify a default" do
      before { stub_const('EVSS::ServiceException::ERROR_MAP', { a: 'evss.a' }) }

      it "uses a global default when error keys aren't recognized" do
        original_body = { messages: [{ key: 'x', severity: 'FATAL' }] }.as_json
        expect(described_class.new(original_body).key).to be 'evss.unmapped_service_exception'
      end
    end
  end
end
