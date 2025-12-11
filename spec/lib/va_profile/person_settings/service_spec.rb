# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/person_settings/service'

RSpec.describe VAProfile::PersonSettings::Service do
  subject { described_class.new(user) }

  let(:valid_user) { build(:user, :loa3) }
  let(:user_not_found) { build(:user, :loa3, vet360_id: 2, icn: 2) }
  let(:user_no_ids) { build(:user, :loa3, vet360_id: nil, icn: nil) }

  describe '#get_person_options' do
    context 'when successful' do
      let(:user) { valid_user }

      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/person_settings/get_person_options', VCR::MATCH_EVERYTHING) do
          response = subject.get_person_options
          expect(response).to be_ok
        end
      end

      it 'contains an array of person options' do
        VCR.use_cassette('va_profile/person_settings/get_person_options', VCR::MATCH_EVERYTHING) do
          response = subject.get_person_options
          expect(response.person_options).to be_an(Array) # of VAProfile::Models::PersonOption
        end
      end
    end

    context 'when not successful with client error' do
      let(:user) { user_not_found }

      it 'returns empty person options array' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_404', VCR::MATCH_EVERYTHING) do
          response = subject.get_person_options
          expect(response).not_to be_ok
          expect(response.person_options).to be_empty
        end
      end

      it 'logs a warning when user not found (404)' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_404', VCR::MATCH_EVERYTHING) do
          expect(Rails.logger).to receive(:warn).with(
            'User not found in VAProfile', vaprofile_id: user.vet360_id
          )
          expect { subject.get_person_options }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.errors.first.code).to eq('VET360_CORE103')
          end
        end
      end
    end

    context 'when server error (5xx)' do
      let(:user) { user_no_ids }

      it 'raises BackendServiceException error' do
        VCR.use_cassette('va_profile/person_settings/get_person_options_500', VCR::MATCH_EVERYTHING) do
          expect { subject.get_person_options }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#update_person_options' do
    let(:user) { valid_user }

    context 'when successful' do
      let(:person_options_data) { { bio: { personOptions: [] } } }

      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/person_settings/post_person_options', VCR::MATCH_EVERYTHING) do
          response = subject.update_person_options(person_options_data)
          expect(response).to be_ok
        end
      end
    end

    context 'when not successful' do
      # missing required field (source date)
      let(:person_options_data) { { bio: { personOptions: [{ itemId: 2, optionId: 7 }] } } }

      it 'raises an exception' do
        VCR.use_cassette('va_profile/person_settings/post_person_options_400', VCR::MATCH_EVERYTHING) do
          expect { subject.update_person_options(person_options_data) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            # expect error code STNG100
          end
        end
      end
    end
  end

  describe '#person_options_request_path' do
    let(:user) { valid_user }

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
