# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/person_settings/service'

RSpec.describe VAProfile::PersonSettings::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:frozen_time) { '2026-03-04T21:30:00.000Z' }

  before do
    Timecop.freeze(frozen_time)
  end

  after do
    Timecop.return
  end

  describe '#get_person_options' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_success') do
          response = subject.get_person_options
          expect(response).to be_ok
        end
      end

      it 'returns a PersonOptionsResponse with an array of person options' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_success') do
          response = subject.get_person_options
          expect(response).to be_a(VAProfile::PersonSettings::PersonOptionsResponse)
          expect(response.person_options).to be_an(Array)
        end
      end
    end

    context 'when user not found' do
      let(:user) { build(:user, :loa3, vet360_id: 0) } # Use known bad id to trigger 404 response

      it 'returns a status of 404 and empty person options array' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_404') do
          response = subject.get_person_options
          expect(response.status).to eq(404)
        end
      end

      it 'returns a PersonOptionsResponse with an empty array of person options' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_404') do
          response = subject.get_person_options
          expect(response).to be_a(VAProfile::PersonSettings::PersonOptionsResponse)
          expect(response.person_options).to eq([])
        end
      end

      it 'logs a warning for user not found' do
        expect(Rails.logger).to receive(:warn).with(
          'User not found in VAProfile', vaprofile_id: user.vet360_id
        )

        VCR.use_cassette('va_profile/person_settings/get_person_options_404') do
          subject.get_person_options
        end
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
    context 'when successful' do
      let(:person_options_data) { { bio: { personOptions: [{ itemId: 1, optionId: 5, sourceDate: frozen_time }] } } }

      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/person_settings/post_person_options_success') do
          response = subject.update_person_options(person_options_data)
          expect(response).to be_ok
        end
      end

      it 'returns a PersonOptionsTransactionResponse' do
        VCR.use_cassette('va_profile/person_settings/post_person_options_success') do
          response = subject.update_person_options(person_options_data)
          expect(response).to be_a(VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse)
          expect(response.transaction).to be_a(VAProfile::Models::Transaction)
          expect(response.transaction.id).to be_present
        end
      end
    end

    context 'when missing required fields' do
      let(:person_options_data) { { bio: { personOptions: [{ itemId: 1, optionId: 5 }] } } } # missing source date

      it 'raises an exception' do
        VCR.use_cassette('va_profile/person_settings/post_person_options_400') do
          expect { subject.update_person_options(person_options_data) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end

    context 'when posting effectiveEndDate for DELETE action' do
      let(:delete_source_date) { (Time.zone.parse(frozen_time) + 10.seconds).iso8601 }

      context 'when successful' do
        let(:person_options_data) do
          { bio:
            { personOptions:
              [{
                itemId: 1,
                optionId: 5,
                sourceDate: delete_source_date,
                effectiveEndDate: frozen_time
              }] } }
        end

        it 'returns a status of 200' do
          VCR.use_cassette('va_profile/person_settings/delete_person_options_success') do
            response = subject.update_person_options(person_options_data)
            expect(response).to be_ok
          end
        end
      end

      context 'when there is an error' do
        let(:person_options_data) do
          { bio:
            { personOptions:
              [{
                itemId: 1,
                optionId: 999, # Invalid option ID
                sourceDate: delete_source_date,
                effectiveEndDate: frozen_time
              }] } }
        end

        it 'raises an exception' do
          VCR.use_cassette('va_profile/person_settings/delete_person_options_400') do
            expect { subject.update_person_options(person_options_data) }.to raise_error do |e|
              expect(e).to be_a(Common::Exceptions::BackendServiceException)
            end
          end
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
