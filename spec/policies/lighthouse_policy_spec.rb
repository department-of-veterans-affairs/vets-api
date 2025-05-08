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

  permissions :access_vet_status? do
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

      it 'logs access denied' do
        expect(Rails.logger).to receive(:info).with(
          'Vet Status Lighthouse access denied',
          icn_present: false,
          participant_id_present: true
        )
        subject.new(user, :lighthouse).access_vet_status?
      end
    end

    context 'user without Participant ID' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:participant_id).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end

      it 'logs access denied' do
        expect(Rails.logger).to receive(:info).with(
          'Vet Status Lighthouse access denied',
          icn_present: true,
          participant_id_present: false
        )
        subject.new(user, :lighthouse).access_vet_status?
      end
    end
  end

  permissions :direct_deposit_access? do
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

    permissions :itf_access? do
      context 'user has Participant ID and SSN and First/Last Name' do
        let(:user) { build(:user, :loa3) }

        it 'grants access' do
          expect(subject).to permit(user, :lighthouse)
        end
      end

      context 'user with blank first name (single name user)' do
        let(:user) { build(:user, :loa3) }

        before { allow(user).to receive(:first_name).and_return('') }

        it 'grants access' do
          expect(subject).to permit(user, :lighthouse)
        end
      end

      context 'user without Participant ID' do
        let(:user) { build(:user, :loa3) }

        before { allow(user).to receive(:participant_id).and_return(nil) }

        it 'denies access' do
          expect(subject).not_to permit(user, :lighthouse)
        end
      end

      context 'user without SSN' do
        let(:user) { build(:user, :loa3) }

        before { allow(user).to receive(:ssn).and_return(nil) }

        it 'denies access' do
          expect(subject).not_to permit(user, :lighthouse)
        end
      end

      context 'user without first name' do
        let(:user) { build(:user, :loa3) }

        before { allow(user).to receive(:first_name).and_return(nil) }

        it 'denies access' do
          expect(subject).not_to permit(user, :lighthouse)
        end
      end

      context 'user without last name' do
        let(:user) { build(:user, :loa3) }

        before { allow(user).to receive(:last_name).and_return(nil) }

        it 'denies access' do
          expect(subject).not_to permit(user, :lighthouse)
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
