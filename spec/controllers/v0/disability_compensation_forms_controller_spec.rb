# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DisabilityCompensationFormsController, type: :controller do
  let(:user) { build(:user, :loa3, :legacy_icn) }
  let(:user_without_icn) { build(:user, :loa3, icn: '') }
  let(:user_without_ssn) { build(:user, :loa3, ssn: '') }
  let(:user_without_edipi) { build(:user, :loa3, edipi: '') }
  let(:user_without_participant_id) { build(:user, :loa3, participant_id: '') }

  before do
    # Stub MPI for all user types used in this test
    stub_mpi(build(:mpi_profile, ssn: user.ssn, icn: user.icn))
    sign_in_as(user)
  end

  describe '#separation_locations' do
    context 'lighthouse' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'returns separation locations' do
        VCR.use_cassette('brd/separation_locations') do
          get(:separation_locations)
          expect(JSON.parse(response.body)['separation_locations'].present?).to be(true)
        end
      end

      it 'uses the cached response on the second request' do
        VCR.use_cassette('brd/separation_locations') do
          2.times do
            get(:separation_locations)
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'lighthouse staging' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
      end

      it 'returns separation locations' do
        VCR.use_cassette('brd/separation_locations_staging') do
          get(:separation_locations)
          expect(JSON.parse(response.body)['separation_locations'].present?).to be(true)
        end
      end

      it 'uses the cached response on the second request' do
        VCR.use_cassette('brd/separation_locations_staging') do
          2.times do
            get(:separation_locations)
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end

  describe '#rating_info' do
    context 'retrieve from Lighthouse' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')

        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, instance_of(User))
                                            .and_return(true)
      end

      it 'returns disability rating' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
          get(:rating_info)
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)['data']['attributes']
          expect(data['user_percent_of_disability']).to eq(100)
          expect(data['source_system']).to eq('Lighthouse')
        end
      end

      context 'user missing icn' do
        before do
          sign_in_as(user_without_icn)
        end

        it 'responds with forbidden' do
          get(:rating_info)
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'retrieve from EVSS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, instance_of(User))
                                            .and_return(false)
      end

      it 'returns disability rating' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info') do
          get(:rating_info)
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)['data']['attributes']
          expect(data['user_percent_of_disability']).to eq(100)
          expect(data['source_system']).to eq('EVSS')
        end
      end

      context 'user is missing snn, edipi, or participant id' do
        it 'responds with forbidden' do
          [user_without_ssn, user_without_edipi, user_without_participant_id].each do |user|
            # Use nil instead of empty string for missing fields in MPI profile
            mpi_ssn = user.ssn.present? ? user.ssn : nil
            stub_mpi(build(:mpi_profile, ssn: mpi_ssn, icn: user.icn))
            sign_in_as(user)
            get(:rating_info)
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
