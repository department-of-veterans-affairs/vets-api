# frozen_string_literal: true

require 'ostruct'
require 'rails_helper'
require 'lighthouse/direct_deposit/error'

describe Lighthouse::DirectDeposit::Error do
  include SchemaMatchers

  it 'parses a 401 Invalid token error' do
    response = OpenStruct.new(
      status: 401,
      body: {
        'status' => 401,
        'error' => 'Invalid token.',
        'path' => '/direct-deposit-management/v1/direct-deposit'
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Invalid token.',
          'detail' => nil,
          'code' => 'LIGHTHOUSE_DIRECT_DEPOSIT401',
          'status' => 401,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end

  it 'parses a 404 Person for ICN not found error' do
    response = OpenStruct.new(
      status: 404,
      body: {
        'type' => 'https =>//api.va.gov/services/direct-deposit-management/errors/generic/not-found',
        'title' => 'Person for ICN not found',
        'status' => 404,
        'detail' => 'No data found for ICN',
        'instance' => 'd85cfe9b-b45b-11ed-b321-67bbb4ad9331'
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Person for ICN not found',
          'detail' => 'No data found for ICN',
          'code' => 'LIGHTHOUSE_DIRECT_DEPOSIT404',
          'status' => 404,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end

  it 'parses a 400 Invalid ICN error' do
    response = OpenStruct.new(
      status: 400,
      body: {
        'type' => 'https://api.va.gov/services/direct-deposit-management/v1/api-schema/errors/constraint-violation',
        'title' => 'Invalid field value',
        'status' => 400,
        'detail' => 'icn size must be between 17 and 17, getDirectDeposit.icn must match \"^\\d{10}V\\d{6}$\"',
        'instance' => '98943542-d84e-48d4-abe7-873070c6a0fd',
        'errorCodes' => []
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Invalid field value',
          'detail' => 'icn size must be between 17 and 17, getDirectDeposit.icn must match \"^\\d{10}V\\d{6}$\"',
          'code' => 'LIGHTHOUSE_DIRECT_DEPOSIT400',
          'status' => 400,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end

  it 'parses a 422 Has No BDN Payments error' do
    response = OpenStruct.new(
      status: 422,
      body: {
        'type' => 'https =>//api.va.gov/services/direct-deposit-management/errors/unable-to-update',
        'title' => 'Unable To Update',
        'status' => 422,
        'detail' => 'Updating bank information not allowed.',
        'instance' => 'e48e3aeb-f312-11ec-88e8-f55e56a472a2',
        'errorCodes' => [
          {
            'errorCode' => 'payment.restriction.indicators.present',
            'detail' => 'hasNoBdnPayments is false.'
          }
        ]
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Unable To Update',
          'detail' => 'Updating bank information not allowed. hasNoBdnPayments is false.',
          'code' => 'payment.restriction.indicators.present',
          'status' => 422,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end

  it 'parses a 400 Potential fraud error' do
    response = OpenStruct.new(
      status: 400,
      body: {
        'type' => 'https://api.va.gov/direct-deposit-management/errors/bad-request',
        'title' => 'Bad Request',
        'status' => 400,
        'detail' => 'No changes were made. Unknown issue(s). Raw response from BGS: Failed to update Address/Bank Info.
        Routing number related to potential fraud.',
        'instance' => 'e48e3aeb-f312-11ec-88e8-f55e56a472a2'
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Bad Request',
          'detail' => 'Routing number related to potential fraud',
          'code' => 'cnp.payment.routing.number.fraud.message',
          'status' => 400,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end

  it 'parses a 429 API rate limit exceeded' do
    response = OpenStruct.new(
      status: 429,
      body: {
        'message' => 'API rate limit exceeded'
      }
    )

    expected = {
      errors: [
        {
          'title' => 'Too many requests',
          'detail' => 'API rate limit exceeded',
          'code' => 'LIGHTHOUSE_DIRECT_DEPOSIT429',
          'status' => 429,
          'source' => 'Lighthouse Direct Deposit'
        }
      ]
    }

    e = Lighthouse::DirectDeposit::Error.new(response)
    actual = e.body
    expect(actual).to match expected
  end
end
