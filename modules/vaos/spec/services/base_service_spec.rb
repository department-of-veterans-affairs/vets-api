# frozen_string_literal: true

require 'rails_helper'

describe VAOS::BaseService do
  describe '#referrer' do
    context 'when ends in .gov' do
      it 'returns the hostname with "vets" replaced with "va"' do
        allow(Settings).to receive(:hostname).and_return('veteran.apps.vets.gov')
        expect(subject.send(:referrer)).to eq('https://veteran.apps.va.gov')
      end
    end

    context 'when does not end in .gov' do
      it 'returns https://review-instance.va.gov' do
        allow(Settings).to receive(:hostname).and_return('id.review.vetsgov-internal')
        expect(subject.send(:referrer)).to eq('https://review-instance.va.gov')
      end
    end
  end
end
