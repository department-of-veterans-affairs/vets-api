require 'spec_helper'
require 'vets_json_schema'

describe 'vets_json_schema' do
  it 'is loaded' do
    expect(VetsJsonSchema::SCHEMAS).not_to be_empty
  end
end
