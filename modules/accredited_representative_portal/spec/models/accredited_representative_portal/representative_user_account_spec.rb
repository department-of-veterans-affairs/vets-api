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
            :vso,
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

    describe '#registration_numbers' do
      let(:icn) { '1234567890V123456' }
      let(:user_email) { 'email@email.com' }
      let(:ogc_client) { instance_double(AccreditedRepresentativePortal::OgcClient) }

      before do
        allow(user_account).to receive(:icn).and_return(icn)
        allow(AccreditedRepresentativePortal::OgcClient).to receive(:new).and_return(ogc_client)
        allow(Flipper).to receive(:enabled?).with(:accredited_representative_portal_self_service_auth).and_return(true)
      end

      context 'when OGC client returns a conflict during registration' do
        let!(:representative) do
          create(:representative,
                 user_types: ['veteran_service_officer'],
                 representative_id: 'REG123456',
                 email: user_email)
        end

        before do
          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(nil)

          # Mock the conflict response from OGC client
          allow(ogc_client).to receive(:post_icn_and_registration_combination)
            .with(icn, 'REG123456')
            .and_return(:conflict)
        end

        it 'raises a Forbidden error with appropriate message' do
          expect { user_account.send(:registration_numbers) }
            .to raise_error(Common::Exceptions::Forbidden, /Forbidden/)
        end
      end

      context 'when OGC returns registration numbers' do
        let!(:representative1) do
          create(:representative,
                 user_types: ['veteran_service_officer'],
                 representative_id: 'REG123456',
                 email: user_email)
        end

        let!(:representative2) do
          create(:representative,
                 user_types: ['attorney'],
                 representative_id: 'REG789012',
                 email: 'another@email.com')
        end

        it 'returns a hash of user_types to registration numbers' do
          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(%w[REG123456 REG789012])

          result = user_account.send(:registration_numbers)

          expect(result).to eq({
                                 'veteran_service_officer' => 'REG123456',
                                 'attorney' => 'REG789012'
                               })
        end
      end

      context 'when OGC returns no registration numbers' do
        let!(:representative) do
          create(:representative,
                 user_types: ['veteran_service_officer'],
                 representative_id: 'REG123456',
                 email: user_email)
        end

        it 'falls back to email lookup' do
          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(nil)

          allow(ogc_client).to receive(:post_icn_and_registration_combination)
            .with(icn, 'REG123456')
            .and_return(true)

          result = user_account.send(:registration_numbers)

          expect(result).to eq({ 'veteran_service_officer' => 'REG123456' })
        end
      end

      context 'when OGC returns empty array and no representatives found by email' do
        it 'raises a Forbidden error' do
          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(nil)

          expect { user_account.send(:registration_numbers) }
            .to raise_error(Common::Exceptions::Forbidden, 'Forbidden')
        end
      end

      context 'when OGC returns numbers that do not match any representatives' do
        it 'returns an empty hash' do
          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(['NONEXISTENT'])

          result = user_account.send(:registration_numbers)
          expect(result).to eq({})
        end
      end
    end

    # rubocop:disable Layout/LineLength
    describe '#registrations' do
      let(:icn) { '1234567890V123456' }
      let(:user_email) { 'email@email.com' }
      let(:registration_number) { 'REG123456' }
      let(:user_type) { 'veteran_service_officer' }
      let(:poa_type) { 'veteran_service_organization' }

      before do
        allow(user_account).to receive(:icn).and_return(icn)
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:accredited_representative_portal_self_service_auth).and_return(true)
          # Mock the registration_numbers result
          allow(user_account).to receive(:registration_numbers).and_return({
                                                                             user_type => registration_number
                                                                           })
        end

        it 'creates registrations from registration_numbers' do
          registrations = user_account.send(:registrations)

          expect(registrations.size).to eq(1)
          expect(registrations.first.accredited_individual_registration_number).to eq(registration_number)
          expect(registrations.first.power_of_attorney_holder_type).to eq(poa_type)
        end
      end

      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:accredited_representative_portal_self_service_auth).and_return(false)

          # Create a database record to be found
          create(
            :user_account_accredited_individual,
            user_account_email: user_email,
            user_account_icn: icn,
            accredited_individual_registration_number: registration_number,
            power_of_attorney_holder_type: poa_type
          )
        end

        it 'retrieves registrations from database' do
          registrations = user_account.send(:registrations)

          expect(registrations.size).to eq(1)
          expect(registrations.first.accredited_individual_registration_number).to eq(registration_number)
          expect(registrations.first.power_of_attorney_holder_type).to eq(poa_type)
        end
      end
    end
    # rubocop:enable Layout/LineLength
  end
end
# rubocop:enable Metrics/ModuleLength
