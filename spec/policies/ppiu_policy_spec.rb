# frozen_string_literal: true

require 'rails_helper'

describe PPIUPolicy do
  let(:user) { build(:evss_user) }

  before do
    Flipper.disable(:profile_ppiu_reject_requests)
  end

  permissions :access? do
    context 'with an idme user' do
      context 'with a loa1 user' do
        let(:user) { build(:user) }

        it 'disallows access' do
          expect(described_class).not_to permit(user, :ppiu)
        end
      end

      context 'with a loa3 user' do
        it 'allows access' do
          expect(described_class).to permit(user, :ppiu)
        end
      end
    end

    context 'with a login.gov user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in)
          .and_return(service_name: SignIn::Constants::Auth::LOGINGOV)
      end

      it 'allows access' do
        expect(described_class).to permit(user, :ppiu)
      end
    end

    context 'with a oauth idme user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: 'oauth_IDME')
      end

      it 'allows access' do
        expect(described_class).to permit(user, :ppiu)
      end
    end

    context 'with a non idme user' do
      let(:user) { build(:user, :mhv) }

      it 'disallows access' do
        expect(described_class).not_to permit(user, :ppiu)
      end
    end

    context 'with a user with the feature enabled' do
      it 'allows access' do
        expect(described_class).to permit(user, :ppiu)
      end
    end
  end

  permissions :access_update? do
    context 'with a user who is competent, has no fiduciary, and is not deceased' do
      it 'allows access' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          expect(described_class).to permit(user, :ppiu)
        end
      end
    end

    context 'with a user who is not competent or has fiduciary or is deceased' do
      it 'disallows access' do
        VCR.use_cassette('evss/ppiu/pay_info_unauthorized') do
          expect(described_class).not_to permit(user, :ppiu)
        end
      end
    end
  end

  context "PPIU rejection flag enabled" do
    before do
      Flipper.enable(:profile_ppiu_reject_requests)
    end

    context 'with a loa3 user' do
      it 'rejects access' do
        expect { PPIUPolicy.new(user, :ppiu).access? }.to raise_error Common::Exceptions::Forbidden do |e|
          expect(e.errors.first.source).to eq('PPIU Policy')
          expect(e.errors.first.detail).to eq('The EVSS PPIU endpoint will be decommissioned. Access is blocked.')
        end
      end
    end
  end
end
