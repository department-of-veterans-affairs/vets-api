# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  RSpec.describe RepresentativeUserAccount, type: :model do
    let(:user_account) do
      RepresentativeUserAccount.find(create(:user_account).id).tap do |memo|
        memo.set_all_emails([user_email])
      end
    end

    describe '#active_power_of_attorney_holders' do
      subject { user_account.active_power_of_attorney_holders }

      let(:user_email) { 'email@email.com' }

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

      context 'when OGC returns no registration numbers and email case differs' do
        let!(:representative) do
          create(:representative,
                 user_types: ['veteran_service_officer'],
                 representative_id: 'REG123456',
                 email: 'TEST@EXAMPLE.COM') # Uppercase email in database
        end

        before do
          # Set user email to lowercase
          user_account.set_all_emails(['test@example.com'])

          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(nil)

          allow(ogc_client).to receive(:post_icn_and_registration_combination)
            .with(icn, 'REG123456')
            .and_return(true)
        end

        it 'finds representative with case-insensitive email matching' do
          result = user_account.send(:registration_numbers)

          expect(result).to eq({ 'veteran_service_officer' => 'REG123456' })
        end
      end

      context 'when OGC returns no registration numbers and multiple email cases exist' do
        let!(:representative1) do
          create(:representative,
                 user_types: ['veteran_service_officer'],
                 representative_id: 'REG123456',
                 email: 'primary@EXAMPLE.COM')
        end

        let!(:representative2) do
          create(:representative,
                 user_types: ['attorney'],
                 representative_id: 'REG789012',
                 email: 'SECONDARY@example.com')
        end

        before do
          # Set user emails with different cases
          user_account.set_all_emails(['PRIMARY@example.com', 'secondary@EXAMPLE.COM'])

          allow(ogc_client).to receive(:find_registration_numbers_for_icn)
            .with(icn)
            .and_return(nil)

          allow(ogc_client).to receive(:post_icn_and_registration_combination)
            .with(icn, 'REG123456')
            .and_return(true)

          allow(ogc_client).to receive(:post_icn_and_registration_combination)
            .with(icn, 'REG789012')
            .and_return(true)
        end

        it 'finds all representatives with case-insensitive email matching' do
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

    describe '#registrations' do
      let(:icn) { '1234567890V123456' }
      let(:user_email) { 'email@email.com' }
      let(:registration_number) { 'REG123456' }
      let(:user_type) { 'veteran_service_officer' }
      let(:poa_type) { 'veteran_service_organization' }

      before do
        registration_numbers = { user_type => registration_number }
        allow(user_account).to receive_messages(icn:, registration_numbers:)
      end

      it 'creates registrations from registration_numbers' do
        registrations = user_account.send(:registrations)

        expect(registrations.size).to eq(1)
        expect(registrations.first.accredited_individual_registration_number).to eq(registration_number)
        expect(registrations.first.power_of_attorney_holder_type).to eq(poa_type)
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
