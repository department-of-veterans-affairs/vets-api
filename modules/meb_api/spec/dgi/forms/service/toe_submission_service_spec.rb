# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/submission_service'

RSpec.describe MebApi::DGI::Forms::Submission::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
    let(:user) { create(:user, :loa3) }
    let(:service) { MebApi::DGI::Forms::Submission::Service.new(user) }
    let(:claimant_params) do
      { form: {
        form_id: '22-1990EMEB',
        toe_claimant: {
          date_of_birth: '2005-04-05',
          first_name: 'GREG',
          last_name: 'ANDERSON',
          middle_name: 'A',
          notification_method: 'EMAIL',
          contact_info: {
            address_line1: '123 Maple St',
            city: 'Plymouth',
            zipcode: '02330',
            email_address: 'vets.gov.user+1@gmail.com',
            address_type: 'DOMESTIC',
            country_code: 'US',
            state_code: 'MA'
          },
          preferred_contact: 'Email'
        },
        parent_or_guardian_signature: 'John Hancock',
        sponsor_options: {
          not_sure_about_sponsor: false,
          first_sponsor_va_id: '8009623328',
          manual_sponsor: {
            first_name: 'John',
            last_name: 'Hancock',
            date_of_birth: '1988-10-13',
            relationship: 'Child'
          }
        },
        high_school_diploma_info: {
          high_school_diploma_or_certificate: true,
          high_school_diploma_or_certificate_date: '2022-06-13'
        },
        direct_deposit: {
          direct_deposit_account_type: 'checking',
          direct_deposit_account_number: '1234569891',
          direct_deposit_routing_number: '123123123'
        }
      } }
    end

    let(:dd_params) do
      {
        dposit_acnt_nbr: '9876543211234',
        dposit_acnt_type_nm: 'Checking',
        financial_institution_name: 'Comerica',
        routng_trnsit_nbr: '042102115'
      }
    end

    let(:dd_params_lighthouse) do
      {
        paymentAccount: {
          accountType: 'CHECKING',
          accountNumber: '1234567890',
          financialInstitutionRoutingNumber: '031000503',
          financialInstitutionName: 'WELLSFARGO BANK'
        },
        controlInformation: {
          canUpdateDirectDeposit: true,
          isCorpAvailable: true,
          isCorpRecFound: true,
          hasNoBdnPayments: true,
          hasIndentity: true,
          hasIndex: true,
          isCompetent: true,
          hasMailingAddress: true,
          hasNoFiduciaryAssigned: true,
          isNotDeceased: true,
          hasPaymentAddress: true,
          isEduClaimAvailable: true
        }
      }
    end

    describe '#submit_toe_claim' do
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'Feature toe_light_house_dgi_direct_deposit=true' do
        before do
          Flipper.enable(:toe_light_house_dgi_direct_deposit)
        end

        it 'Lighthouse returns a status of 200' do
          VCR.use_cassette('dgi/forms/submit_toe_claim') do
            response = service.submit_claim(ActionController::Parameters.new(claimant_params),
                                            ActionController::Parameters.new(dd_params_lighthouse))

            expect(response.status).to eq(200)
          end
        end
      end

      context 'Feature CH35 toe_light_house_dgi_direct_deposit=true' do
        before do
          Flipper.enable(:toe_light_house_dgi_direct_deposit)
          claimant_params[:form]['@type'] = 'Chapter35'
        end

        it 'Lighthouse returns a status of 200' do
          VCR.use_cassette('dgi/forms/submit_toe_claim') do
            response = service.submit_claim(ActionController::Parameters.new(claimant_params),
                                            ActionController::Parameters.new(dd_params_lighthouse))

            expect(response.status).to eq(200)
          end
        end
      end

      context 'Feature toe_light_house_dgi_direct_deposit=false' do
        before do
          Flipper.disable(:toe_light_house_dgi_direct_deposit)
        end

        it 'EVSS returns a status of 200' do
          VCR.use_cassette('dgi/forms/submit_toe_claim') do
            response = service.submit_claim(ActionController::Parameters.new(claimant_params),
                                            ActionController::Parameters.new(dd_params))

            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
