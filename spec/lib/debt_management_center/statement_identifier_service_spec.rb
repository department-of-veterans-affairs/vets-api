# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/statement_identifier_service'

RSpec.describe DebtManagementCenter::StatementIdentifierService, type: :service do
  describe '#get_mpi_data' do
    context 'given edipi statement' do
      edipi = '492031291'
      let(:verification) { build(:idme_user_verification) }
      let(:edipi_statement) do
        {
          'veteranIdentifier' => edipi,
          'identifierType' => 'edipi',
          'facilityNum' => '123',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

      context 'when MPI gets a GatewayTimeout' do
        let(:address) { 'person43@example.com' }
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it 'recognizes this error is retryable' do
          service = described_class.new(edipi_statement)

          expect { service.get_mpi_data }
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
          expect { service.get_mpi_data }.to raise_error(described_class::RetryableError)
        end
      end

      context 'MPI profile found' do
        before do
          mpi_profile.vet360_id = '1'
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
          allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
          allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
            'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
          )
        end

        it 'returns an icn' do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            service = described_class.new(edipi_statement)
            details = service.get_mpi_data
            expect(details).to eq({ icn: mpi_profile.icn, first_name: mpi_profile.given_names.first })
          end
        end
      end

      context 'MPI profile not found' do
        let(:profile_not_found_error) { create(:find_profile_not_found_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_not_found_error)
        end

        it 'raises not found error from MPI' do
          service = described_class.new(edipi_statement)
          expect { service.get_mpi_data }
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
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::FailedRequestError)
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
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

      context 'when MPI gets a GatewayTimeout' do
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it 'recognizes this error is retryable' do
          service = described_class.new(vista_statement)

          expect { service.get_mpi_data }
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
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }.to raise_error(described_class::RetryableError)
        end
      end

      context 'MPI profile found' do
        let(:account) { build(:user_account_with_verification) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
        end

        it 'can get an email from icn' do
          service = described_class.new(vista_statement)
          details = service.get_mpi_data
          expect(details).to eq({ icn: mpi_profile.icn, first_name: mpi_profile.given_names.first })
        end
      end

      context 'MPI profile not found' do
        let(:profile_not_found_error) { create(:find_profile_not_found_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_not_found_error)
        end

        it 'raises not found error from MPI' do
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::RecordNotFound)
        end
      end

      context 'MPI service error' do
        let(:profile_response_error) { create(:find_profile_server_error_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response_error)
        end

        it 'raises server error from MPI' do
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::FailedRequestError)
        end
      end
    end
  end

  describe '#get_mpi_data v2' do
    context 'given edipi statement' do
      edipi = '492031291'
      let(:verification) { build(:idme_user_verification) }
      let(:edipi_statement) do
        {
          'veteranIdentifier' => edipi,
          'identifierType' => 'edipi',
          'facilityNum' => '123',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

      context 'when MPI gets a GatewayTimeout' do
        let(:address) { 'person43@example.com' }
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it 'recognizes this error is retryable' do
          service = described_class.new(edipi_statement)

          expect { service.get_mpi_data }
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
          expect { service.get_mpi_data }.to raise_error(described_class::RetryableError)
        end
      end

      context 'MPI profile found' do
        before do
          mpi_profile.vet360_id = '1781151'
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
          allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
          allow(Settings.vanotify.services.dmc).to receive(:api_key).and_return(
            'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
          )
        end

        it 'returns an icn' do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            service = described_class.new(edipi_statement)
            details = service.get_mpi_data
            expect(details).to eq({ icn: mpi_profile.icn, first_name: mpi_profile.given_names.first })
          end
        end
      end

      context 'MPI profile not found' do
        let(:profile_not_found_error) { create(:find_profile_not_found_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_not_found_error)
        end

        it 'raises not found error from MPI' do
          service = described_class.new(edipi_statement)
          expect { service.get_mpi_data }
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
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::FailedRequestError)
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
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

      context 'when MPI gets a GatewayTimeout' do
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it 'recognizes this error is retryable' do
          service = described_class.new(vista_statement)

          expect { service.get_mpi_data }
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
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }.to raise_error(described_class::RetryableError)
        end
      end

      context 'MPI profile found' do
        let(:account) { build(:user_account_with_verification) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response)
        end

        it 'can get an email from icn' do
          service = described_class.new(vista_statement)
          details = service.get_mpi_data
          expect(details).to eq({ icn: mpi_profile.icn, first_name: mpi_profile.given_names.first })
        end
      end

      context 'MPI profile not found' do
        let(:profile_not_found_error) { create(:find_profile_not_found_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_not_found_error)
        end

        it 'raises not found error from MPI' do
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::RecordNotFound)
        end
      end

      context 'MPI service error' do
        let(:profile_response_error) { create(:find_profile_server_error_response) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_facility).and_return(profile_response_error)
        end

        it 'raises server error from MPI' do
          service = described_class.new(vista_statement)
          expect { service.get_mpi_data }
            .to raise_error(MPI::Errors::FailedRequestError)
        end
      end
    end
  end
end
