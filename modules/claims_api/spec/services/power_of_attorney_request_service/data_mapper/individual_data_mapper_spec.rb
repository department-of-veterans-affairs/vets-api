# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../poa_auto_establishment_spec_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper do
  subject { described_class.new(data: individual_gathered_data) }

  include_context 'shared POA auto establishment data'

  it 'maps the data correctly' do
    allow_any_instance_of(described_class).to receive(:representative_type).and_return('ATTORNEY')

    res = subject.map_data

    expect(res).to eq(individual_mapped_form_data)
  end

  it 'raises an error if no rep is found' do
    expect do
      subject.send(:validate_representative!, nil, '083')
    end.to raise_error(Common::Exceptions::ResourceNotFound)
  end
end
