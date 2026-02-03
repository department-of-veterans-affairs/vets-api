# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/person_settings/service'

RSpec.describe VAProfile::PersonSettings::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#get_person_options' do
    # TODO: Replace stubs with VCR cassettes once recording access is available
    # Cassettes: va_profile/person_settings/get_person_options*
    context 'when successful' do
      let(:mock_response) do
        double('response',
               status: 200,
               body: { personOptions: [{ itemId: 2, optionId: 7 }] })
      end

      before do
        allow_any_instance_of(VAProfile::Service).to receive(:perform)
          .with(:get, anything)
          .and_return(mock_response)
      end

      it 'returns a status of 200' do
        response = subject.get_person_options
        expect(response).to be_ok
      end

      it 'returns a PersonOptionsResponse with an array of person options' do
        response = subject.get_person_options
        expect(response).to be_a(VAProfile::PersonSettings::PersonOptionsResponse)
        expect(response.person_options).to be_an(Array)
      end
    end

    context 'when user not found' do
      before do
        allow_any_instance_of(VAProfile::Service).to receive(:perform)
          .and_raise(Common::Client::Errors::ClientError.new('Not Found', 404))
      end

      it 'returns a status of 404 and empty person options array' do
        response = subject.get_person_options
        expect(response.status).to eq(404)
        expect(response.person_options).to be_empty
      end

      it 'logs a warning for user not found' do
        expect(Rails.logger).to receive(:warn).with(
          'User not found in VAProfile', vaprofile_id: user.vet360_id
        )

        subject.get_person_options
      end
    end

    context 'when service returns a 500 error code' do
      before do
        allow_any_instance_of(VAProfile::Service).to receive(:perform)
          .and_raise(Common::Client::Errors::ClientError.new('Internal Server Error', 500))
      end

      it 'raises a BackendServiceException error' do
        expect { subject.get_person_options }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end

  describe '#update_person_options' do
    # TODO: Replace stubs with VCR cassettes once recording access is available
    # Cassettes: va_profile/person_settings/post_person_options*
    context 'when successful' do
      let(:person_options_data) { { bio: { personOptions: [] } } }
      let(:mock_response) do
        double('response',
               status: 200,
               body: {
                 'tx_audit_id' => 'test-transaction-123',
                 'status' => 'COMPLETED_SUCCESS',
                 'tx_status' => 'COMPLETED_SUCCESS',
                 'tx_type' => 'PUSH',
                 'tx_interaction_type' => 'ATTENDED',
                 'tx_push_input' => {
                   'person_options' => []
                 },
                 'tx_output' =>
                 [{ 'person_options' => [] }]
               })
      end

      before do
        allow_any_instance_of(VAProfile::Service).to receive(:perform)
          .with(:post, anything, person_options_data.to_json)
          .and_return(mock_response)
      end

      it 'returns a status of 200' do
        response = subject.update_person_options(person_options_data)
        expect(response).to be_ok
      end

      it 'returns a PersonOptionsTransactionResponse' do
        response = subject.update_person_options(person_options_data)
        expect(response).to be_a(VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse)
        expect(response.transaction).to be_a(VAProfile::Models::Transaction)
        expect(response.transaction.id).to be_present
      end
    end

    context 'when missing required fields' do
      let(:person_options_data) { { bio: { personOptions: [{ itemId: 2, optionId: 7 }] } } } # missing source date

      before do
        allow_any_instance_of(VAProfile::Service).to receive(:perform)
          .with(:post, anything, person_options_data.to_json)
          .and_raise(Common::Client::Errors::ClientError.new('Bad Request', 400))
      end

      it 'raises an exception' do
        expect { subject.update_person_options(person_options_data) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#person_options_request_path' do
    it 'constructs a valid path with OID and encoded user ID with AAID' do
      expected_path = "person-options/v1/#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(subject.send(:vaprofile_id_with_aaid))}"

      expect(subject.send(:person_options_request_path)).to eq(expected_path)
    end

    it 'includes the VA root OID' do
      path = subject.send(:person_options_request_path)

      expect(path).to include(MPI::Constants::VA_ROOT_OID)
    end

    it 'URL encodes the user ID with AAID portion' do
      id_with_aaid = subject.send(:vaprofile_id_with_aaid)
      path = subject.send(:person_options_request_path)

      expect(path).to include(ERB::Util.url_encode(id_with_aaid))
    end

    it 'appends containerId query parameter when a single container id is provided' do
      container_id = 1
      path = subject.send(:person_options_request_path, container_id)

      expect(path).to end_with("?containerId=#{container_id}")
    end

    it 'appends multiple containerId query parameters when an array of container ids is provided' do
      container_ids = [1, 2, 5]
      path = subject.send(:person_options_request_path, container_ids)

      container_ids.each do |id|
        expect(path).to include("containerId=#{id}")
      end

      expect(path).to end_with("&containerId=#{container_ids.last}")
    end
  end

  describe '#vaprofile_id_with_aaid' do
    context 'when user has vet360_id' do
      let(:user) { build(:user, :loa3, vet360_id: '12345') }

      it 'returns vet360_id with VA_PROFILE_ID_POSTFIX' do
        expected_id_with_aaid = "#{user.vet360_id}#{described_class::VA_PROFILE_ID_POSTFIX}"

        expect(subject.send(:vaprofile_id_with_aaid)).to eq(expected_id_with_aaid)
      end
    end

    context 'when user does not have vet360_id but has ICN' do
      let(:user) { build(:user, :loa3, vet360_id: nil, icn: '1234567890V123456') }

      it 'returns ICN with ICN_POSTFIX' do
        expected_id_with_aaid = "#{user.icn}#{described_class::ICN_POSTFIX}"

        expect(subject.send(:vaprofile_id_with_aaid)).to eq(expected_id_with_aaid)
      end
    end

    context 'when user has both vet360_id and ICN' do
      let(:user) { build(:user, :loa3, vet360_id: '12345', icn: '1234567890V123456') }

      it 'prefers vet360_id over ICN' do
        expected_id_with_aaid = "#{user.vet360_id}#{described_class::VA_PROFILE_ID_POSTFIX}"

        expect(subject.send(:vaprofile_id_with_aaid)).to eq(expected_id_with_aaid)
        expect(subject.send(:vaprofile_id_with_aaid)).not_to include(user.icn)
      end
    end
  end

  describe '#verify_user!' do
    context 'when user has vet360_id' do
      let(:user) { build(:user, :loa3, vet360_id: '12345') }

      it 'logs verification status' do
        expect(Rails.logger).to receive(:info).with(
          'PersonSettings User MVI Verified? : true, VAProfile Verified? true'
        )

        subject.send(:verify_user!)
      end
    end

    context 'when user has ICN but no vet360_id' do
      let(:user) { build(:user, :loa3, vet360_id: nil, icn: '1234567890V123456') }

      it 'logs verification status' do
        expect(Rails.logger).to receive(:info).with(
          'PersonSettings User MVI Verified? : true, VAProfile Verified? false'
        )

        subject.send(:verify_user!)
      end
    end

    context 'when user has neither vet360_id nor ICN' do
      let(:user) { build(:user, :loa3, vet360_id: nil, icn: nil) }

      it 'raises an error' do
        expect { subject.send(:verify_user!) }.to raise_error('PersonSettings - Missing User ICN and VAProfile_ID')
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'raises an error' do
        expect { subject.send(:verify_user!) }.to raise_error('PersonSettings - Missing User ICN and VAProfile_ID')
      end
    end
  end
end
