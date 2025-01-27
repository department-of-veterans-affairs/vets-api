# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Services do
  describe '#authorizations' do
    subject { Users::Services.new(user).authorizations }

    let(:user) { build(:user, :loa3) }

    context 'with initialized user' do
      VCR.use_cassette('user_eligibility_client/perform_an_eligibility_check_for_non_premium_user',
                       match_requests_on: %i[method sm_user_ignoring_path_param]) do
        it 'returns an array of services authorized to the initialized user',
           :aggregate_failures do
          expect(subject.class).to eq Array
          expect(subject).to match_array(
            %w[
              facilities
              hca
              edu-benefits
              evss-claims
              lighthouse
              form526
              user-profile
              appeals-status
              form-save-in-progress
              form-prefill
              identity-proofed
              vet360
            ]
          )
        end
      end
    end

    context 'with an loa1 user' do
      let(:user) { build(:user) }

      VCR.use_cassette('user_eligibility_client/perform_an_eligibility_check_for_non_premium_user',
                       match_requests_on: %i[method sm_user_ignoring_path_param]) do
        it 'returns only the services that are authorized to this loa1 user' do
          expect(subject).to match_array(
            %w[
              facilities
              hca
              edu-benefits
              user-profile
              form-save-in-progress
              form-prefill
            ]
          )
        end
      end
    end

    context 'with an MHV Premium user' do
      let(:user) { build(:user, :mhv) }

      before do
        Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
        VCR.insert_cassette('sm_client/session')
        VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                            match_requests_on: %i[method sm_user_ignoring_path_param])
      end

      after do
        VCR.eject_cassette(name: 'sm_client/session')
        VCR.eject_cassette(name: 'user_eligibility_client/perform_an_eligibility_check_for_premium_user')
        Timecop.return
      end

      it 'returns an array including the MHV services' do
        %w[health-records medical-records messaging rx].each do |service|
          expect(subject).to include(service)
        end
      end
    end
  end
end
