# frozen_string_literal: true

require 'rails_helper'

describe LighthousePolicy do
  subject { described_class }

  permissions :access? do
    context 'user has ICN and Participant ID' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :lighthouse)
      end
    end

    context 'user without ICN' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:icn).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end

    context 'user without Participant ID' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:participant_id).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end
  end

  permissions :access_disability_compensations? do
    let(:user) { build(:evss_user) }

    context 'user has ICN and Participant ID' do
      it 'grants access' do
        expect(subject).to permit(user, :lighthouse)
      end
    end

    context 'user without ICN' do
      before { allow(user).to receive(:icn).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end

    context 'user without Participant ID' do
      before { allow(user).to receive(:participant_id).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end

    context 'with an idme user' do
      context 'with a loa1 user' do
        let(:user) { build(:user) }

        it 'disallows access' do
          expect(described_class).not_to permit(user, :lighthouse)
        end
      end

      context 'with a loa3 user' do
        it 'allows access' do
          expect(described_class).to permit(user, :lighthouse)
        end
      end
    end

    context 'with a login.gov user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in)
          .and_return(service_name: SignIn::Constants::Auth::LOGINGOV)
      end

      it 'allows access' do
        expect(described_class).to permit(user, :lighthouse)
      end
    end

    context 'with a oauth idme user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: 'oauth_IDME')
      end

      it 'allows access' do
        expect(described_class).to permit(user, :lighthouse)
      end
    end

    context 'with a non idme user' do
      let(:user) { build(:user, :mhv) }

      it 'disallows access' do
        expect(described_class).not_to permit(user, :lighthouse)
      end
    end

    context 'with a user with the feature enabled' do
      it 'allows access' do
        expect(described_class).to permit(user, :lighthouse)
      end
    end
  end
end
