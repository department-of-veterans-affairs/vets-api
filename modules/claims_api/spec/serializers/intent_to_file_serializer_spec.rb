require 'rails_helper'

describe ClaimsApi::PowerOfAttorneySerializer do
  let(:poa_submission) { build(:power_of_attorney) }
  let(:rendered_hash) { described_class.new(poa_submission).serializable_hash }

  it 'includes :id' do
    expect(rendered_hash[:id]).to eq poa_submission.id
  end

  it 'includes :creation_date' do
    expect(rendered_hash[:creation_date]).to eq poa_submission.creation_date
  end

  it 'includes :type' do
    expect(rendered_hash[:type]).to eq poa_submission.type
  end

  it 'includes :status' do
    expect(rendered_hash[:status]).to eq poa_submission.status
  end

end
