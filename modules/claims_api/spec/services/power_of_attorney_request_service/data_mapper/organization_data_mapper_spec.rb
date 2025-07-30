# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../poa_auto_establishment_spec_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper do
  subject { described_class.new(data: org_gathered_data) }

  include_context 'shared POA auto establishment data'

  it 'maps the data correctly' do
    res = subject.map_data

    expect(res).to eq(org_mapped_form_data)
  end
end
