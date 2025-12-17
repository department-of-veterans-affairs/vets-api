# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA212680 do
  subject(:profile) { described_class.new(form_id: '21-2680', user:) }

  let(:user) { create(:user, :loa3) }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({
                                       version: 0,
                                       prefill: true,
                                       returnUrl: '/veteran-information'
                                     })
    end
  end

  describe '#prefill' do
    context 'when user is a verified veteran' do
      before do
        allow(user).to receive(:veteran?).and_return(true)
      end

      it 'prefills veteran information from user profile' do
        data = profile.prefill

        expect(data[:form_data]).to be_present
        expect(data[:form_data]['veteranInformation']).to be_present
        expect(data[:metadata]).to eq(profile.metadata)
      end

      it 'includes veteran full name' do
        data = profile.prefill
        veteran_name = data[:form_data]['veteranInformation']['veteranFullName']

        expect(veteran_name['first']).to be_present
        expect(veteran_name['last']).to be_present
      end

      it 'includes veteran date of birth' do
        data = profile.prefill

        expect(data[:form_data]['veteranInformation']['veteranDob']).to be_present
      end

      it 'includes veteran SSN' do
        data = profile.prefill

        expect(data[:form_data]['veteranInformation']['veteranSsn']).to be_present
      end
    end

    context 'when user is not a veteran' do
      before do
        allow(user).to receive(:veteran?).and_return(false)
      end

      it 'returns empty form_data' do
        data = profile.prefill

        expect(data[:form_data]).to eq({})
      end

      it 'still returns metadata' do
        data = profile.prefill

        expect(data[:metadata]).to eq(profile.metadata)
      end
    end

    context 'when veteran status check raises an error' do
      before do
        allow(user).to receive(:veteran?).and_raise(StandardError.new('VA Profile unavailable'))
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty form_data' do
        data = profile.prefill

        expect(data[:form_data]).to eq({})
      end

      it 'logs the error' do
        profile.prefill

        expect(Rails.logger).to have_received(:error).with(/VA212680 veteran status check failed/)
      end

      it 'still returns metadata' do
        data = profile.prefill

        expect(data[:metadata]).to eq(profile.metadata)
      end
    end
  end
end
