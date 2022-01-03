# frozen_string_literal: true

require 'rails_helper'
require 'dgi/submission/service'

RSpec.describe MebApi::DGI::Submission::Service do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Submission::Service.new(user) }
  let(:claimant_params) do
    {
      military_claimant: {
        claimant: {
          first_name: 'Hoover',
          middle_name: 'Hoover',
          last_name: 'Hoover',
          date_of_birth: '1970-01-01',
          contact_info: {
            address_line_1: '503 upper park',
            address_line_2: '',
            city: 'falls church',
            zipcode: '22046',
            email_address: 'hhover@test.com',
            address_type: 'DOMESTIC',
            mobile_phone_number: '4409938894',
            country_code: 'US',
            state_code: 'VA'
          },
          notification_method: 'EMAIL'
        }
      },
      relinquished_benefit: {
        eff_relinquish_date: '2021-10-15',
        relinquished_benefit: 'Chapter30'
      },
      additional_considerations: {
        active_duty_kicker: 'N/A',
        academy_rotc_scholarship: 'YES',
        reserve_kicker: 'N/A',
        senior_rotc_scholarship: 'YES',
        active_duty_dod_repay_loan: 'YES'
      },
      comments: {
        disagree_with_service_period: false
      },
      direct_deposit: {
        account_number: '123123123123',
        account_type: 'savings',
        routing_number: '123123123'
      },
      education_benefit: {
        military_claimant: {
          claimant: {
            first_name: 'Herbert',
            middle_name: 'Hoover',
            last_name: 'Hoover',
            date_of_birth: '1980-03-11',
            contact_info: {
              address_line_1: '503 upper park',
              address_line_2: '',
              city: 'falls church',
              zipcode: '22046',
              email_address: 'hhover@test.com',
              address_type: 'DOMESTIC',
              mobile_phone_number: '4409938894',
              country_code: 'US',
              state_code: 'VA'
            },
            notification_method: 'EMAIL'
          }
        },
        relinquished_benefit: {
          eff_relinquish_date: '2021-10-15',
          relinquished_benefit: 'Chapter30'
        },
        additional_considerations: {
          active_duty_kicker: 'N/A',
          academy_rotc_scholarship: 'YES',
          reserve_kicker: 'N/A',
          senior_rotc_scholarship: 'YES',
          active_duty_dod_repay_loan: 'YES'
        },
        comments: {
          disagree_with_service_period: false
        },
        direct_deposit: {
          account_number: '123123123123',
          account_type: 'savings',
          routing_number: '123123123'
        }
      }
    }
  end

  describe '#submit_claim' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/submit_claim') do
          response = service.submit_claim(claimant_params)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
