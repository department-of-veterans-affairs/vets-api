# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::Preneeds::FormFillSerializer, type: :serializer do
  let(:attachments) { Array.wrap(build(:preneeds_attachment_type)) }
  let(:branches) { Array.wrap(build(:branches_of_service)) }
  let(:cemeteries) { Array.wrap(build(:cemetery)) }
  let(:discharges) { Array.wrap(build(:discharge_type)) }
  let(:states) { Array.wrap(build(:preneeds_state)) }

  let(:form_fill) do
    build :form_fill, attachment_types: attachments, branches_of_services: branches, cemeteries: cemeteries,
                      discharge_types: discharges, states: states
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(form_fill, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(form_fill.id)
  end

  it 'should include attachment_types' do
    expect(attributes['attachment_types']).to eq(attachments.as_json)
  end

  it 'should include branches_of_services' do
    expect(attributes['branches_of_services']).to eq(branches.as_json)
  end

  it 'should include cemeteries' do
    expect(attributes['cemeteries']).to eq(cemeteries.as_json)
  end

  it 'should include discharge_types' do
    expect(attributes['discharge_types']).to eq(discharges.as_json)
  end

  it 'should include states' do
    expect(attributes['states']).to eq(states.as_json)
  end
end
