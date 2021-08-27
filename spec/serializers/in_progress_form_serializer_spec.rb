# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressFormSerializer do
  subject { JSON.parse serialize(in_progress_form, serializer_class: described_class) }

  let(:in_progress_form) { build :in_progress_form }
  let(:top_level_keys) { subject.keys }
  let(:data) { subject['data'] }
  let(:type) { data['type'] }
  let(:attributes) { data['attributes'] }
  let(:metadata) { attributes['metadata'] }

  it 'has the correct shape (JSON:API)' do
    expect(subject).to be_a Hash
    expect(top_level_keys).to contain_exactly 'data'
    expect(data.keys).to contain_exactly('id', 'type', 'attributes')
    expect(type).to eq 'in_progress_forms'
    expect(attributes.keys).to contain_exactly('form_id', 'created_at', 'updated_at', 'metadata')
  end

  context 'with nested metadata' do
    let(:in_progress_form) { build :in_progress_form, :with_nested_metadata }

    it 'deeply transformed the keys to snake_case' do
      expect(metadata['how_now']['brown_cow']).to be_present
    end

    it 'corrupts complicated keys' do
      expect(in_progress_form.metadata['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.'])
        .to be_present
      expect(metadata['how_now']['brown_cow']['-an eas-i-ly corRupted KEY.'])
        .not_to be_present
    end
  end
end
