# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PreneedsArrayInclusionValidator do
  class ModelWithArray < Common::Base
    include ActiveModel::Validations

    LIST = %w(a b c).freeze

    attribute :letters, Array[String]
    validates :letters, preneeds_array_inclusion: { includes_list: LIST }
  end

  let(:subject) { ModelWithArray.new(letters: %w(a b)) }

  it 'validates each array element for inclusion' do
    expect(subject).to be_valid
  end

  it 'invalidates model whose array is empty' do
    subject.letters = []
    expect(subject).not_to be_valid
  end

  it 'invalidates a model whose array elements are not included in a list' do
    subject.letters << 'd'
    expect(subject).not_to be_valid
  end
end
