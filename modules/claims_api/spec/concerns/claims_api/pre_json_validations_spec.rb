# frozen_string_literal: true

require 'rails_helper'

class TestController < ApplicationController
  include ClaimsApi::PreJsonValidations

  def set_json_body(json_values)
    @json_body = json_values
  end
end

describe ClaimsApi::PreJsonValidations do
  let(:test_class) { TestController.new }

  context 'handling email values for POA submissions' do
    describe '#pre_json_verification_of_email_for_poa' do
      let(:service_org_json) do
        {
          'poaCode' => 'aaa',
          'registrationNumber' => '999999999999'
        }
      end
      let(:poa_json) do
        temp = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2',
                                          'veterans', 'power_of_attorney', '2122a', 'valid_with_claimant.json').read)
        temp['data']['type'] = 'form/21-22'
        temp['data']['attributes']['serviceOrganization'] = service_org_json
        temp
      end

      context 'if the email is blank' do
        it 'removes a blank veteran object email' do
          poa_json['data']['attributes']['veteran']['email'] = ' '
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['veteran']).not_to have_key('email')
        end

        it 'removes a blank claimant object email' do
          poa_json['data']['attributes']['claimant']['email'] = ''
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['claimant']).not_to have_key('email')
        end

        it 'removes a blank serviceOrganization object email' do
          poa_json['data']['attributes']['serviceOrganization']['email'] = ''
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['serviceOrganization']).not_to have_key('email')
        end
      end

      context 'correctly handles mixed email values' do
        it 'removes correct value if veteran email is present but claimant is blank' do
          poa_json['data']['attributes']['veteran']['email'] = 'test@testmail.com'
          poa_json['data']['attributes']['claimant']['email'] = ''
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['veteran']).to have_key('email')
          expect(res['data']['attributes']['claimant']).not_to have_key('email')
        end

        it 'removes correct value if veteran & claimant email is present but serviceOrganization is blank' do
          poa_json['data']['attributes']['veteran']['email'] = 'test@testmail.com'
          poa_json['data']['attributes']['claimant']['email'] = 'test@testmail.com'
          poa_json['data']['attributes']['serviceOrganization']['email'] = ''
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['veteran']).to have_key('email')
          expect(res['data']['attributes']['claimant']).to have_key('email')
          expect(res['data']['attributes']['serviceOrganization']).not_to have_key('email')
        end
      end

      context 'if the email is not blank' do
        it 'does not remove a valid email' do
          poa_json['data']['attributes']['veteran']['email'] = 'test@testmail.com'
          poa_json['data']['attributes']['claimant']['email'] = 'test1@test1mail.com'
          poa_json['data']['attributes']['serviceOrganization']['email'] = 'test2@test2mail.com'
          test_class.set_json_body(poa_json)

          res = test_class.pre_json_verification_of_email_for_poa
          expect(res['data']['attributes']['veteran']).to have_key('email')
          expect(res['data']['attributes']['claimant']).to have_key('email')
          expect(res['data']['attributes']['serviceOrganization']).to have_key('email')
        end
      end
    end
  end
end
