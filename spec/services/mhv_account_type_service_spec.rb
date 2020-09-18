# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVAccountTypeService do
  subject { described_class.new(user) }

  let(:sign_in) { { service_name: 'myhealthevet' } }
  let(:user_identity) { instance_double('UserIdentity', mhv_account_type: nil, sign_in: sign_in) }
  let(:user) do
    instance_double(
      'User',
      mhv_correlation_id: '12210827',
      identity: user_identity,
      uuid: 1,
      authn_context: 'myhealthevet',
      va_patient?: true
    )
  end

  before { Settings.sentry.dsn = 'asdf' }

  after { Settings.sentry.dsn = nil }

  context 'no mhv_correlation_id' do
    let(:user) { instance_double('User', mhv_correlation_id: nil) }

    it '#mhv_account_type returns nil' do
      expect(Raven).not_to receive(:capture_message)
      expect(subject.mhv_account_type).to be_nil
    end
  end

  context 'known mhv_account_type' do
    let(:user_identity) { instance_double('UserIdentity', mhv_account_type: 'Whatever', sign_in: sign_in) }

    it '#mhv_account_type returns known account type' do
      VCR.use_cassette('mhv_account_type_service/premium') do
        expect(Raven).not_to receive(:capture_message)
        expect(subject.mhv_account_type).to eq('Whatever')
      end
    end
  end

  context 'premium user' do
    it '#mhv_account_type returns Premium' do
      VCR.use_cassette('mhv_account_type_service/premium') do
        eligible_data_classes = subject.eligible_data_classes
        # expect(Raven).not_to receive(:capture_message)
        expect(eligible_data_classes.count).to eq(32)
        expect(subject.mhv_account_type).to eq('Premium')
        described_class.new(user)
      end
    end
  end

  context 'fetches cached value' do
    let(:namespace) { Redis::Namespace.new('common_collection', redis: Redis.current) }
    let(:cache_key) { '12210827:geteligibledataclass' }

    it '#mhv_account_type returns Premium' do
      VCR.use_cassette('mhv_account_type_service/premium') do
        expect(described_class.new(user).mhv_account_type).to eq('Premium')
      end

      5.times do
        expect(namespace.get(cache_key)).not_to be_nil
        expect(described_class.new(user).mhv_account_type).to eq('Premium')
      end
    end
  end

  context 'advanced user' do
    it '#mhv_account_type returns Advanced' do
      VCR.use_cassette('mhv_account_type_service/advanced') do
        eligible_data_classes = subject.eligible_data_classes
        expect(Raven).not_to receive(:capture_message)
        expect(eligible_data_classes.count).to eq(18)
        expect(subject.mhv_account_type).to eq('Advanced')
      end
    end
  end

  context 'basic user' do
    it '#mhv_account_type returns Basic' do
      VCR.use_cassette('mhv_account_type_service/basic') do
        eligible_data_classes = subject.eligible_data_classes
        expect(Raven).not_to receive(:capture_message)
        expect(eligible_data_classes.count).to eq(16)
        expect(subject.mhv_account_type).to eq('Basic')
      end
    end
  end

  describe 'errors' do
    let(:level) { 'info' }
    let(:extra_context) do
      {
        uuid: user.uuid,
        mhv_correlation_id: user.mhv_correlation_id,
        eligible_data_classes: eligible_data_classes,
        authn_context: user.authn_context,
        va_patient: user.va_patient?,
        mhv_acct_type: user.identity.mhv_account_type
      }
    end
    let(:tags_context) { { sign_in_method: { service_name: 'myhealthevet' } } }

    context 'error fetching eligible data classes' do
      let(:error_message) { described_class::MHV_DOWN_MESSAGE }
      let(:eligible_data_classes) { nil }

      it '#mhv_account_type returns Unknown' do
        VCR.use_cassette('mhv_account_type_service/error') do
          expect(Raven).to receive(:extra_context).with({ error_message: 'string not matched' }.merge(extra_context))
          expect(Raven).to receive(:tags_context).once.with(tags_context)
          expect(Raven).to receive(:tags_context).once.with(
            error: 'mhv_session'
          )
          expect(Raven).to receive(:capture_message).with(error_message, level: level)
          expect(subject.mhv_account_type).to eq('Error')
        end
      end
    end

    context 'inconsitent data returned by MHV' do
      let(:error_message) { described_class::UNEXPECTED_DATA_CLASS_COUNT_MESSAGE }
      let(:eligible_data_classes) { %w[seiactivityjournal seiallergies] }

      it '#mhv_account_type returns Unknown' do
        VCR.use_cassette('mhv_account_type_service/unknown') do
          expect(Raven).to receive(:extra_context).with(extra_context)
          expect(Raven).to receive(:tags_context).once.with(tags_context)
          expect(Raven).to receive(:tags_context).once.with(
            error: 'mhv_session'
          )
          expect(Raven).to receive(:capture_message).with(error_message, level: level)
          expect(subject.mhv_account_type).to eq('Unknown')
        end
      end
    end
  end
end
