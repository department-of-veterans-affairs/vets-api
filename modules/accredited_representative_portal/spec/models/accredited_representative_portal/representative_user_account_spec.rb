# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  RSpec.describe RepresentativeUserAccount, type: :model do
    let(:user_account) do
      RepresentativeUserAccount.find(create(:user_account).id).tap do |memo|
        memo.set_email(user_email)
        memo.set_all_emails([user_email])
      end
    end

    describe '#set_email' do
      subject { user_account.set_email('alsoemail@email.com') }

      context 'with no email set' do
        let(:user_email) { nil }

        it 'does not raise ArgumentError' do
          expect { subject }.not_to raise_error
        end
      end

      context 'with an email already set' do
        let(:user_email) { 'email@email.com' }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#active_power_of_attorney_holders' do
      subject { user_account.active_power_of_attorney_holders }

      let(:user_email) { 'email@email.com' }

      context 'with no email set' do
        let(:user_email) { nil }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'with no associated VSO registration' do
        it 'raises Common::Exceptions::Forbidden' do
          expect { subject }.to raise_error(Common::Exceptions::Forbidden)
        end
      end

      context 'with an associated VSO registration' do
        let!(:registration) do
          create(
            :user_account_accredited_individual,
            user_account_email: user_email
          )
        end

        context 'but no associated representative in turn' do
          it 'raises Common::Exceptions::Forbidden' do
            expect { subject }.to raise_error(Common::Exceptions::Forbidden)
          end
        end

        context 'and an associated representative in turn' do
          let!(:representative) do
            create(
              :representative,
              user_types:,
              poa_codes:,
              email: user_email,
              representative_id:
                registration.accredited_individual_registration_number
            )
          end

          context 'but no associated organization in turn' do
            let(:user_types) { ['attorney'] }
            let(:poa_codes) { ['A1Q'] }

            it { is_expected.to be_empty }
          end

          context 'and some associated organizations in turn' do
            let(:user_types) { ['veteran_service_officer'] }
            let(:poa_codes) do
              [].tap do |memo|
                memo << create(:organization, can_accept_digital_poa_requests: true).poa
                memo << create(:organization, can_accept_digital_poa_requests: true).poa
                memo << create(:organization, can_accept_digital_poa_requests: true).poa
              end
            end

            it { is_expected.to have_attributes(size: poa_codes.size) }
          end
        end
      end
    end

    describe '#get_registration_number' do
      subject { user_account.get_registration_number(power_of_attorney_holder_type) }

      context 'without a user email set' do
        let(:user_email) { nil }
        let(:power_of_attorney_holder_type) { 'veteran_service_organization' }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'with a user email set' do
        let(:user_email) { 'email@email.com' }

        let!(:registration) do
          create(
            :representative,
            email: user_email
          )
        end

        context 'without matching POA holder type' do
          let(:power_of_attorney_holder_type) { 'asdf' }

          it { is_expected.to be_nil }
        end

        context 'with matching POA holder type' do
          let(:power_of_attorney_holder_type) { 'veteran_service_organization' }

          it { is_expected.to eq(registration.representative_id) }
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
