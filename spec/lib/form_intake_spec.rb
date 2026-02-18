# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Naming/VariableNumber
RSpec.describe FormIntake do
  describe '.enabled_for_form?' do
    let(:user_account) { create(:user_account) }

    before do
      stub_const('FormIntake::ELIGIBLE_FORMS', ['21P-601'])
      stub_const('FormIntake::FORM_FEATURE_FLAGS', { '21P-601' => :form_intake_integration_601 })
    end

    context 'when form not in eligible list' do
      it 'returns false' do
        expect(described_class.enabled_for_form?('UNKNOWN')).to be false
      end

      it 'returns false even if flag would be enabled' do
        Flipper.enable(:some_other_flag)
        expect(described_class.enabled_for_form?('UNKNOWN')).to be false
      end
    end

    context 'when form has no feature flag' do
      before do
        stub_const('FormIntake::FORM_FEATURE_FLAGS', {})
      end

      it 'returns false' do
        expect(described_class.enabled_for_form?('21P-601')).to be false
      end
    end

    context 'when feature flag is disabled' do
      before do
        Flipper.disable(:form_intake_integration_601)
      end

      it 'returns false' do
        expect(described_class.enabled_for_form?('21P-601', user_account)).to be false
      end

      it 'returns false without user_account' do
        expect(described_class.enabled_for_form?('21P-601')).to be false
      end
    end

    context 'when feature flag is enabled' do
      before do
        Flipper.enable(:form_intake_integration_601)
      end

      it 'returns true' do
        expect(described_class.enabled_for_form?('21P-601', user_account)).to be true
      end

      it 'returns true without user_account' do
        expect(described_class.enabled_for_form?('21P-601')).to be true
      end
    end

    context 'when Flipper raises error' do
      before do
        allow(Flipper).to receive(:enabled?).and_raise(StandardError, 'Flipper error')
      end

      it 'returns false' do
        expect(described_class.enabled_for_form?('21P-601', user_account)).to be false
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(
          'FormIntake feature flag check failed',
          hash_including(
            error: 'Flipper error', # Matches the stub above
            form_id: '21P-601',
            flag: :form_intake_integration_601
          )
        )
        described_class.enabled_for_form?('21P-601', user_account)
      end

      it 'increments error metric' do
        expect(StatsD).to receive(:increment).with(
          'form_intake.flipper_check_failed',
          tags: ['form_id:21P-601']
        )
        described_class.enabled_for_form?('21P-601', user_account)
      end
    end

    context 'with actor-based flag' do
      let(:user1) { create(:user_account) }
      let(:user2) { create(:user_account) }

      before do
        Flipper.enable_actor(:form_intake_integration_601, user1)
      end

      it 'returns true for enabled user' do
        expect(described_class.enabled_for_form?('21P-601', user1)).to be true
      end

      it 'returns false for non-enabled user' do
        expect(described_class.enabled_for_form?('21P-601', user2)).to be false
      end
    end

    context 'when Flipper raises network error' do
      before do
        allow(Flipper).to receive(:enabled?).and_raise(StandardError, 'Redis connection failed')
      end

      it 'returns false and logs error' do
        expect(Rails.logger).to receive(:error).with(
          'FormIntake feature flag check failed',
          hash_including(
            error: 'Redis connection failed', # Matches the stub
            form_id: '21P-601',
            flag: :form_intake_integration_601
          )
        )
        expect(StatsD).to receive(:increment).with('form_intake.flipper_check_failed', tags: ['form_id:21P-601'])

        result = described_class.enabled_for_form?('21P-601', user_account)
        expect(result).to be false
      end
    end
  end

  describe '.enabled_forms' do
    before do
      stub_const('FormIntake::ELIGIBLE_FORMS', %w[21P-601 21-0966 21-4138])
      stub_const('FormIntake::FORM_FEATURE_FLAGS', {
                   '21P-601' => :form_intake_integration_601,
                   '21-0966' => :form_intake_integration_0966,
                   '21-4138' => :form_intake_integration_4138
                 })
    end

    it 'returns only forms with enabled flags' do
      Flipper.enable(:form_intake_integration_601)
      Flipper.disable(:form_intake_integration_0966)
      Flipper.disable(:form_intake_integration_4138)

      expect(described_class.enabled_forms).to eq(['21P-601'])
    end

    it 'returns multiple forms when multiple flags enabled' do
      Flipper.enable(:form_intake_integration_601)
      Flipper.enable(:form_intake_integration_0966)
      Flipper.disable(:form_intake_integration_4138)

      expect(described_class.enabled_forms).to match_array(%w[21P-601 21-0966])
    end

    it 'returns empty array when no flags enabled' do
      Flipper.disable(:form_intake_integration_601)
      Flipper.disable(:form_intake_integration_0966)
      Flipper.disable(:form_intake_integration_4138)

      expect(described_class.enabled_forms).to eq([])
    end

    it 'skips forms without feature flags' do
      stub_const('FormIntake::FORM_FEATURE_FLAGS', {
                   '21P-601' => :form_intake_integration_601
                   # 21-0966 missing from hash
                 })

      Flipper.enable(:form_intake_integration_601)

      expect(described_class.enabled_forms).to eq(['21P-601'])
    end
  end
end
# rubocop:enable Naming/VariableNumber
