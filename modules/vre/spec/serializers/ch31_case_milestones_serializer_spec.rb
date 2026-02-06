# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31CaseMilestonesSerializer, type: :serializer do
  subject { serialize(response, serializer_class: described_class) }

  let(:response) do
    VRE::Ch31CaseMilestones::Response.new(200, double(body: response_body))
  end

  let(:response_body) do
    {
      resCaseId: 742,
      responseMessage: 'The case milestones have been updated'
    }
  end

  it 'includes the expected attributes' do
    expect(subject['data']['attributes']).to include(
      'res_case_id' => 742,
      'response_message' => 'The case milestones have been updated'
    )
  end

  it 'sets the id to an empty string' do
    expect(subject['data']['id']).to eq('')
  end

  it 'sets the type to the serializer name' do
    expect(subject['data']['type']).to eq('ch31_case_milestones')
  end
end
