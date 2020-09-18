# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::AmbiguousRequest do
  subject { described_class.new(detail: 'detail') }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end
end
