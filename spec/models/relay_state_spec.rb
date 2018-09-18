# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelayState, type: :model do
  let(:relay_url) { Settings.saml.relays.vagov }
  let(:invalid_relay_url) { 'https://fake-attacker-site.com' }
  let(:logout_relay_url) { Settings.saml.logout_relays.vagov }
  let(:invalid_logout_relay_url) { 'https://fake-attacker-logout.com' }
  let(:relay_enum) { Settings.saml.relays.keys.second.to_s }
  let(:invalid_relay_enum) { 'foo' }

  describe '.login_relay' do
    context 'with a valid RelayState & success_relay' do
      subject { described_class.new(relay_enum: relay_enum, url: relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns RelayState' do
        expect(subject.login_url).to eq(relay_url)
      end
      it '#logout_url returns default logout' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
    end

    context 'when success_relay=vagov & Settings.saml.relays.vagov=nil' do
      subject { described_class.new(relay_enum: 'vagov') }
      it 'returns default' do
        with_settings(Settings.saml.relays, vagov: nil) do
          expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
        end
      end
    end

    context 'when no params are provided' do
      subject { described_class.new(relay_enum: nil, url: nil) }

      it 'is invalid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
    end

    context 'with an valid enum and invalid RelayState' do
      subject { described_class.new(relay_enum: relay_enum, url: invalid_relay_url) }

      it 'is invalid' do
        expect(subject.valid?).to be_falsey
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
      it 'logs a error to sentry' do
        expect_any_instance_of(described_class)
          .to receive(:log_message_to_sentry)
          .once
          .with(
            'Invalid SAML RelayState!',
            :error,
            error_messages: { url: ["[#{invalid_relay_url}] not a valid relay url"] },
            url_whitelist: described_class::ALL_RELAY_URLS,
            enum_whitelist: described_class::RELAY_KEYS
          )
        subject.dup
      end
    end

    context 'with a valid RelayState and an ivalid success_relay' do
      subject { described_class.new(relay_enum: invalid_relay_enum, url: relay_url) }

      it 'is invalid' do
        expect(subject.valid?).to be_falsey
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
      it 'logs a error to sentry' do
        expect_any_instance_of(described_class)
          .to receive(:log_message_to_sentry)
          .once
          .with(
            'Invalid SAML RelayState!',
            :error,
            error_messages: { relay_enum: ["[#{invalid_relay_enum}] not a valid relay enum"] },
            url_whitelist: described_class::ALL_RELAY_URLS,
            enum_whitelist: described_class::RELAY_KEYS
          )
        subject.dup
      end
    end

    context 'with a valid login RelayState and nil success_relay' do
      subject { described_class.new(url: relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns RelayState' do
        expect(subject.login_url).to eq(relay_url)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
    end

    context 'with a valid logout RelayState and nil success_relay' do
      subject { described_class.new(url: logout_relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns RelayState' do
        expect(subject.logout_url).to eq(logout_relay_url)
      end
    end

    context 'with a valid success_relay only' do
      subject { described_class.new(relay_enum: relay_enum) }
      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns the enum-appropriate login url' do
        expect(subject.login_url).to eq(Settings.saml.relays[relay_enum])
      end
      it '#logout_url returns the enum-appropriate logout url' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays[relay_enum])
      end
    end

    context 'with a review instance slug for RelayState' do
      let(:slug) { '8d89abfbff975ec465c7b88fcbbf175b' }
      subject { described_class.new(url: slug) }

      it '#login_url returns the review-instance login url' do
        with_settings(Settings, review_instance_slug: slug) do
          with_settings(Settings.saml.relays, vetsgov: "http://#{slug}.review.vetsgov-internal/auth/login/callback") do
            expect(subject.login_url).to eq("http://#{slug}.review.vetsgov-internal/auth/login/callback")
          end
        end
      end

      it '#logout_url returns the review-instance logout url' do
        with_settings(Settings, review_instance_slug: slug) do
          with_settings(Settings.saml, logout_relay: "http://#{slug}.review.vetsgov-internal/logout/") do
            expect(subject.logout_url).to eq("http://#{slug}.review.vetsgov-internal/logout/")
          end
        end
      end
    end
  end
end
