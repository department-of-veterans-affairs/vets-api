# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'
require 'sidekiq/attr_package'
RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

RSpec.describe EmailVerificationService do
  let(:service) { described_class.new(user) }
  let(:user) { build(:user, :loa3) }
  let(:key) { "email_verification:#{user.uuid}" }
  let(:token) { service.initiate_verification }

  before do
    allow(Settings.email_verification)
      .to receive(:jwt_secret)
      .and_return('test_jwt_secret')
    stub_const('EmailVerificationJob', Class.new do
      def self.perform_async(*); end
    end)
    # Mock Sidekiq::AttrPackage for testing
    allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')
  end

  describe '#initiate_verification' do
    subject(:initiate) { service.initiate_verification }

    it 'generates a JWT token' do
      segments = initiate.split('.')
      expect(segments.length).to eq(3)
      header = JSON.parse(Base64.urlsafe_decode64(segments[0]))
      expect(header['alg']).to eq('HS256')
      expect(header['typ']).to eq('JWT')
    end

    it 'stores token in Redis with expiration' do
      initiate
      expect($redis.get(key)).not_to be_nil
    end

    it 'stores PII data in AttrPackage and passes cache_key to job' do
      expect(Sidekiq::AttrPackage).to receive(:create).with(
        expires_in: described_class::REDIS_EXPIRATION,
        email: user.email,
        first_name: user.first_name,
        verification_link: anything
      ).and_return('test_cache_key')

      expect(EmailVerificationJob)
        .to receive(:perform_async)
        .with('initial_verification', 'test_cache_key')

      initiate
    end

    it 'invalidates older tokens when new one is issued' do
      $redis.set(key, 'oldtoken')
      initiate
      expect($redis.get(key)).not_to eq('oldtoken')
    end

    shared_examples 'template_type job' do |template_arg, expected_type|
      it "passes correct template_type for #{expected_type}" do
        expect(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')
        expect(EmailVerificationJob)
          .to receive(:perform_async)
          .with(expected_type, 'test_cache_key')
        described_class.new(user).initiate_verification(template_arg)
      end
    end

    include_examples 'template_type job', 'initial_verification', 'initial_verification'
    include_examples 'template_type job', 'annual_verification', 'annual_verification'
    include_examples 'template_type job', 'email_change_verification', 'email_change_verification'
  end

  describe '#verify_email!' do
    subject(:verify) { service.verify_email!(verify_token) }

    context 'with valid token' do
      let(:verify_token) { token }

      before { $redis.set(key, token) }

      it 'returns true and deletes token from Redis' do
        expect(verify).to be_truthy
        expect($redis.get(key)).to be_nil
      end

      it 'triggers success email job when verification succeeds' do
        expect(Sidekiq::AttrPackage).to receive(:create).with(
          expires_in: described_class::REDIS_EXPIRATION,
          first_name: user.first_name,
          email: user.email
        ).and_return('success_cache_key')

        expect(EmailVerificationJob)
          .to receive(:perform_async)
          .with('verification_success', 'success_cache_key')
        verify
      end
    end

    context 'with invalid token' do
      let(:verify_token) { 'wrongtoken' }

      before { $redis.set(key, 'othertoken') }

      it 'returns false' do
        expect(verify).to be_falsey
      end

      it 'logs a warning for invalid token' do
        expect(Rails.logger)
          .to receive(:warn)
          .with("Email verification failed: invalid token for user #{user.uuid}", hash_including(
                                                                                    user_uuid: user.uuid,
                                                                                    token_provided: true,
                                                                                    stored_token_exists: 1
                                                                                  ))
        verify
      end
    end

    context 'VA Profile coordination' do
      it 'coordinate with VA Profile when field is available' do
        # expect(service.verify_email!('wrongtoken')).to be_falsey
        skip('pending integration')
      end
    end
  end

  describe 'error handling' do
    context 'when Redis fails' do
      it 'raises BackendServiceException when Redis fails' do
        redis_namespace = service.instance_variable_get(:@redis)
        allow(redis_namespace).to receive(:set).and_raise(Redis::CannotConnectError)
        expect { service.initiate_verification }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
