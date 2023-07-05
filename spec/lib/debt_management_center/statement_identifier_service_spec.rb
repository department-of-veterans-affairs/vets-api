# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/statement_identifier_service'

RSpec.describe DebtManagementCenter::StatementIdentifierService, skip_vet360: true,
                                                                 type: :service do
  describe '#derive_email_address' do
    context 'given edipi statement' do
      edipi = '492031291'
      let(:verification) { build(:dslogon_user_verification) }
      let(:edipi_statement) do
        {
          'veteranIdentifier' => edipi,
          'identifierType' => 'edipi',
          'facilityNum' => '123',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end

      context 'with existing user verification' do
        before do
          allow(UserVerification).to receive(:find_by).with(dslogon_uuid: edipi).and_return(verification)
        end

        it 'can source email from edipi' do
          service = described_class.new(edipi_statement)
          email_address = service.derive_email_address
          expect(email_address).to eq(verification.user_credential_email.credential_email)
        end
      end

      context 'with a saved index' do
        edipi = '492031291'
        address = Faker::Internet.email
        index_key = "edipi:#{edipi}"

        before do
          IdentifierIndex.create(identifier: index_key, email_address: address)
        end

        after do
          IdentifierIndex.delete(index_key)
        end

        it 'gets email from index' do
          service = described_class.new(edipi_statement)
          email_address = service.derive_email_address
          expect(email_address).to eq(address)
        end
      end

      context 'without a saved index' do
        let(:mpi_profile) { build(:mpi_profile) }
        let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

        context 'with an icn related user verification' do
          let(:account) { build(:user_account_with_verification) }

          before do
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
            allow(UserAccount).to receive(:find_by).with(icn: mpi_profile.icn).and_return(account)
          end

          it 'can get an email from icn' do
            address = account.user_verifications.first.user_credential_email.credential_email
            service = described_class.new(edipi_statement)
            email_address = service.derive_email_address
            expect(email_address).to eq(address)
          end
        end

        context 'when MPI gets a GatewayTimeout' do
          let(:address) { 'person43@example.com' }
          let(:expected_error) { Common::Exceptions::GatewayTimeout }
          let(:expected_error_message) { expected_error.new.message }

          before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

          it 'recognizes this error is retryable' do
            service = described_class.new(edipi_statement)
            expect { service.derive_email_address }
              .to raise_error(described_class::RetryableError)
          end
        end

        context 'when MPI fails to breakers outage' do
          let(:current_time) { Time.zone.now }
          let(:expected_error) { Breakers::OutageException }
          let(:expected_error_message) { "Outage detected on MVI beginning at #{current_time.to_i}" }

          before do
            Timecop.freeze
            MPI::Configuration.instance.breakers_service.begin_forced_outage!
          end

          after { Timecop.return }

          it 'recognizes this error is retryable' do
            service = described_class.new(edipi_statement)
            expect { service.derive_email_address }
              .to raise_error(described_class::RetryableError)
          end
        end

        context 'without an icn related user verification' do
          let(:address) { 'person43@example.com' }

          before do
            mpi_profile.vet360_id = '1'
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
            allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
            allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
              'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            )
          end

          it 'finds email via vet360 id' do
            VCR.use_cassette('va_profile/contact_information/person_full', VCR::MATCH_EVERYTHING) do
              service = described_class.new(edipi_statement)
              email_address = service.derive_email_address

              expect(email_address).to eq(address)
            end
          end

          context 'MPI profile not found' do
            let(:profile_not_found_error) { create(:find_profile_not_found_response) }

            before do
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_not_found_error)
            end

            it 'raises not found error from MPI' do
              service = described_class.new(edipi_statement)
              expect { service.derive_email_address }
                .to raise_error(MPI::Errors::RecordNotFound)
            end
          end

          context 'MPI service error' do
            let(:profile_response_error) { create(:find_profile_server_error_response) }

            before do
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response_error)
            end

            it 'raises server error from MPI' do
              service = described_class.new(edipi_statement)
              expect { service.derive_email_address }
                .to raise_error(MPI::Errors::FailedRequestError)
            end
          end

          context 'MPI profile does not contain vet360 id' do
            let(:mpi_profile) { build(:mpi_profile, vet360_id: nil) }
            let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

            before do
              mpi_profile.vet360_id = nil
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
            end

            it 'raises vet360 id not found error' do
              service = described_class.new(edipi_statement)
              expect { service.derive_email_address }.to raise_error do |error|
                expect(error).to be_instance_of(described_class::UnableToSourceEmailForStatement)
              end
            end
          end

          context 'when contact info service returns a 503 error code' do
            it 'recognizes this error is retryable' do
              VCR.use_cassette('va_profile/contact_information/person_status_503', VCR::MATCH_EVERYTHING) do
                service = described_class.new(edipi_statement)
                expect { service.derive_email_address }.to raise_error do |error|
                  expect(error).to be_instance_of(described_class::RetryableError)
                end
              end
            end
          end

          context 'when no email address resovles' do
            before do
              mpi_profile.vet360_id = '6767671'
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
              allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
              allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
                'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
              )
            end

            it 'throws an UnableToSourceEmailForStatement error' do
              VCR.use_cassette('va_profile/contact_information/person_error', VCR::MATCH_EVERYTHING) do
                service = described_class.new(edipi_statement)
                expect { service.derive_email_address }.to raise_error do |error|
                  expect(error).to be_instance_of(described_class::UnableToSourceEmailForStatement)
                end
              end
            end
          end
        end
      end
    end

    context 'given vista statement' do
      let(:vista_statement) do
        {
          'veteranIdentifier' => '348530923',
          'identifierType' => 'dfn',
          'facilityNum' => '456',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end

      context 'with a saved index' do
        address = Faker::Internet.email
        index_key = 'vista_account_id:4560000348530923'

        before do
          IdentifierIndex.create(identifier: index_key, email_address: address)
        end

        after do
          IdentifierIndex.delete(index_key)
        end

        it 'gets email from index' do
          service = described_class.new(vista_statement)
          email_address = service.derive_email_address
          expect(email_address).to eq(address)
        end
      end

      context 'without a saved index' do
        let(:mpi_profile) { build(:mpi_profile) }
        let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

        context 'with an icn related user verification' do
          let(:account) { build(:user_account_with_verification) }

          before do
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
            allow(UserAccount).to receive(:find_by).with(icn: mpi_profile.icn).and_return(account)
          end

          it 'can get an email from icn' do
            address = account.user_verifications.first.user_credential_email.credential_email
            service = described_class.new(vista_statement)
            email_address = service.derive_email_address
            expect(email_address).to eq(address)
          end
        end

        context 'without an icn related user verification' do
          let(:address) { 'person43@example.com' }

          before do
            mpi_profile.vet360_id = '1'
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
            allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
            allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
              'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            )
          end

          it 'finds email via vet360 id' do
            VCR.use_cassette('va_profile/contact_information/person_full', VCR::MATCH_EVERYTHING) do
              service = described_class.new(vista_statement)
              email_address = service.derive_email_address

              expect(email_address).to eq(address)
            end
          end

          context 'when no email address resovles' do
            before do
              mpi_profile.vet360_id = '6767671'
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
              allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
              allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
                'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
              )
            end

            it 'throws an UnableToSourceEmailForStatement error' do
              VCR.use_cassette('va_profile/contact_information/person_error', VCR::MATCH_EVERYTHING) do
                service = described_class.new(vista_statement)
                expect { service.derive_email_address }.to raise_error do |error|
                  expect(error).to be_instance_of(described_class::UnableToSourceEmailForStatement)
                end
              end
            end
          end
        end
      end
    end
  end
end
