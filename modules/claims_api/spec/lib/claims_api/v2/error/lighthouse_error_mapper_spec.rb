# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper' # mock_ccg method
require 'claims_api/v2/error/lighthouse_error_mapper'

describe ClaimsApi::V2::Error::LighthouseErrorMapper do
  it '#get_details' do
    error =
      { key: 'form526.submit.save.draftForm.MaxEPCode', severity: 'FATAL',
        text: 'This claim could not be established. The Maximum number of EP codes have been reached for this ' \
              'benefit type claim code' }

    mapper = ClaimsApi::V2::Error::LighthouseErrorMapper.new(error).get_details

    expect(mapper).to eq('The Maximum number of EP codes have been reached for this benefit type claim code')
  end

  it '# get_details for a rated disability error' do
    error =
      { key: 'form526.disabilities[0].disabilityActionTypeNONE.ratedDisability.isInvalid', severity: 'ERROR',
        text: 'An attempt was made to add a secondary disability to an existing rated Disability. The rated ' \
              'Disability could not be found' }
    mapper = ClaimsApi::V2::Error::LighthouseErrorMapper.new(error).get_details

    expect(mapper).to eq('The claim could not be established - An attempt was made to add a secondary disability ' \
                         'to an existing rated Disability. The rated Disability could not be found.')
  end
end
