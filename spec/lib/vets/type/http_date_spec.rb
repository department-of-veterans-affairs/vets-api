require 'rails_helper'
require 'vets/type/http_date'

RSpec.describe Vets::Type::HTTPDate do
  let(:name) { 'test_http_date' }
  let(:klass) { String }
  let(:http_date_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(http_date_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid datetime string' do
      let(:valid_datetime) { '2024-12-19T12:34:56Z' }

      it 'returns the HTTP date format' do
        expect(http_date_instance.cast(valid_datetime)).to eq(Time.parse(valid_datetime).utc.httpdate)
      end
    end

    context 'when value is an invalid datetime string' do
      let(:invalid_datetime) { 'invalid-datetime' }

      it 'raises a TypeError with the correct message' do
        expect {
          http_date_instance.cast(invalid_datetime)
        }.to raise_error(TypeError, "#{name} is not Time parseable")
      end
    end

    context 'when value is a numeric timestamp' do
      let(:timestamp) { 1_700_000_000 } # Example Unix timestamp

      it 'converts the timestamp to HTTP date format' do
        expect(http_date_instance.cast(timestamp)).to eq(Time.at(timestamp).utc.httpdate)
      end
    end
  end
end
