# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pensions::FormProfiles::VA21p527ez, type: :model do
  let(:user) { build(:user, :loa3) }
  let(:form_id) { '21P-527EZ' }
  let(:military_info_instance) { instance_double(Pensions::MilitaryInformation) }
  let(:monitor) { instance_double(Logging::Monitor) }

  before do
    allow(user).to receive(:authorize).with(:va_profile, :access?).and_return(true)
    allow(user).to receive(:can_access_id_card?).and_return(true)
    allow(Pensions::MilitaryInformation).to receive(:new).with(user).and_return(military_info_instance)
    allow(Logging::Monitor).to receive(:new).with('pensions-form-profile').and_return(monitor)
  end

  describe '#metadata' do
    it 'returns correct metadata' do
      form = described_class.new(form_id:, user:)
      expect(form.metadata).to eq(
        version: 0,
        prefill: true,
        returnUrl: '/applicant/information'
      )
    end
  end

  describe '#initialize_military_information' do
    context 'when user is authorized' do
      it 'returns FormMilitaryInformation object with expected data' do
        expect(military_info_instance).to receive(:public_send).exactly(
          Pensions::MilitaryInformation::PREFILL_METHODS.count
        ).times
        form = described_class.new(form_id:, user:)
        expect(form.initialize_military_information).to be_a(Pensions::FormMilitaryInformation)
      end
    end

    context 'when user is not authorized' do
      before do
        allow(user).to receive(:authorize).with(:va_profile, :access?).and_return(false)
      end

      it 'returns an empty hash' do
        form = described_class.new(form_id:, user:)
        expect(form.initialize_military_information).to eq({})
      end
    end
  end

  describe '#initialize_va_profile_prefill_military_information' do
    let(:form) { described_class.new(form_id:, user:) }

    before do
      allow(military_info_instance).to receive(:public_send).and_return('2009-4-1')
      allow(Pensions::MilitaryInformation::PREFILL_METHODS).to receive(:each).and_yield('first_uniformed_entry_date')
    end

    it 'populates military information data correctly' do
      expect(form.send(:initialize_va_profile_prefill_military_information))
        .to eq('first_uniformed_entry_date' => '2009-4-1')
    end

    context 'when an exception occurs' do
      before do
        allow(military_info_instance).to receive(:public_send).and_raise(StandardError.new('test error'))
        allow(monitor).to receive(:track_request)
      end

      it 'logs the exception and returns an empty hash' do
        expect(monitor).to receive(:track_request).with(
          :error,
          'VA Profile military information prefill failed',
          'api.pensions.form_profile.military_prefill_error',
          call_location: instance_of(Thread::Backtrace::Location),
          exception: {
            message: 'test error',
            backtrace: instance_of(Array)
          }
        )

        expect(form.send(:initialize_va_profile_prefill_military_information)).to eq({})
      end
    end
  end
end
