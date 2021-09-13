# frozen_string_literal: true

require 'rails_helper'
require 'down_time_checker'

describe DownTimeChecker do
  describe '#new' do
    subject { DownTimeChecker.new({ service_name: 'BDN', extra_delay: 0 }) }

    it 'is a kind_of DownTimeChecker' do
      expect(subject).to be_a(DownTimeChecker)
    end
  end

  describe '#down?' do
    subject { DownTimeChecker.new({ service_name: 'BDN', extra_delay: 120 }).down? }

    context 'when BDN is up' do
      before { Timecop.freeze(Time.parse('Tuesday at 1:59am UTC')) }

      after { Timecop.return }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'when BDN is down' do
      before { Timecop.freeze(Time.parse('Tuesday at 9:59am UTC')) }

      after { Timecop.return }

      it 'returns delay until window ends' do
        expect(subject).to be 180.0
      end
    end
  end
end
