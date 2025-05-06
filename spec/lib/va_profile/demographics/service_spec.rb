# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/demographics/service'

describe VAProfile::Demographics::Service,  feature: :personal_info,
                                            team_owner: :vfs_authenticated_experience_backend,
                                            type: :service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:idme_uuid) { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }

  before do
    allow(user).to receive(:idme_uuid).and_return(idme_uuid)
  end

  describe '#identity_path' do
    context 'when a uuid exists' do
      it 'returns a valid identity path' do
        path = subject.identity_path
        expect(path).to eq('2.16.840.1.113883.4.349/b2fab2b5-6af0-45e1-a9e2-394347af91ef%5EPN%5E200VIDM%5EUSDVA')
      end
    end
  end

  describe '#get_demographics' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
          response = subject.get_demographics

          expect(response).to be_ok
          expect(response.demographics).to be_a(VAProfile::Models::Demographic)
        end
      end

      it 'returns a users preferred name' do
        VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
          response = subject.get_demographics
          preferred_name = response.demographics.preferred_name

          expect(preferred_name.text).to eq('SAM')
        end
      end

      it 'returns a users gender-identity' do
        VCR.use_cassette('va_profile/demographics/demographics', VCR::MATCH_EVERYTHING) do
          response = subject.get_demographics
          gender_identity = response.demographics.gender_identity

          expect(gender_identity.code).to eq('F')
          expect(gender_identity.name).to eq('Female')
        end
      end
    end

    context 'when not successful' do
      context 'with a 400 error' do
        it 'returns nil demographic' do
          VCR.use_cassette('va_profile/demographics/demographics_error_400', VCR::MATCH_EVERYTHING) do
            response = subject.get_demographics

            expect(response).not_to be_ok
            expect(response.demographics.preferred_name).to be_nil
            expect(response.demographics.gender_identity).to be_nil
          end
        end
      end

      it 'logs exception to sentry' do
        VCR.use_cassette('va_profile/demographics/demographics_error_404', VCR::MATCH_EVERYTHING) do
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
            instance_of(Common::Client::Errors::ClientError),
            { csp_id_with_aaid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef^PN^200VIDM^USDVA' },
            { va_profile: :demographics_not_found },
            :warning
          )

          response = subject.get_demographics
          expect(response).not_to be_ok
          expect(response.demographics.preferred_name).to be_nil
          expect(response.demographics.gender_identity).to be_nil
        end
      end
    end

    context 'when service returns a 503 error code' do
      it 'raises a BackendServiceException error' do
        VCR.use_cassette('va_profile/demographics/demographics_error_503', VCR::MATCH_EVERYTHING) do
          expect { subject.get_demographics }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(502)
            expect(e.errors.first.code).to eq('VET360_502')
          end
        end
      end
    end
  end
end
