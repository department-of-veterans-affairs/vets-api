# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::CancelForm, type: :model do
  describe '#params' do
    context 'when null attributes are given' do
      subject { described_class.new }

      it 'raises Common::Exceptions::ValidationErrors exception and keeps a record of the invalid attributes' do
        expect { subject.params }.to raise_error(Common::Exceptions::ValidationErrors)
        expect(subject.errors.attribute_names).to contain_exactly(:status, :cancellation_reason)
      end
    end

    context 'when an invalid status is given' do
      subject { described_class.new(status: 'booked', cancellation_reason: 'testing') }

      it 'raises Common::Exceptions::ValidationErrors exception and keeps a record of the invalid attribute' do
        expect { subject.params }.to raise_error(Common::Exceptions::ValidationErrors)
        expect(subject.errors.attribute_names).to contain_exactly(:status)
      end
    end

    context 'when vaild attributes are given' do
      subject { described_class.new(status: 'cancelled', cancellation_reason: 'testing') }

      it 'returns the correct attribute values' do
        expect(subject.params).to eq(status: 'cancelled', cancellation_reason: 'testing')
      end
    end
  end
end
