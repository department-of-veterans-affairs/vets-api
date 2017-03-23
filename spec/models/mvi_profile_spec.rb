# frozen_string_literal: true
require 'rails_helper'

describe MviProfile do
  describe '#mhv_correlation_id' do
    context 'with multiple ids' do
      subject { build(:mvi_profile) }
      it 'returns the first id' do
        expect(subject.mhv_correlation_id).to eq(subject.mhv_ids.first)
      end
    end

    context 'with a single id' do
      let(:id) { '12345678' }
      subject { build(:mvi_profile, mhv_ids: [id]) }
      it 'returns the id' do
        expect(subject.mhv_correlation_id).to eq(id)
      end
    end

    context 'with no ids' do
      subject { build(:mvi_profile, mhv_ids: nil) }
      it 'returns nil' do
        expect(subject.mhv_correlation_id).to be_nil
      end
    end
  end
end
