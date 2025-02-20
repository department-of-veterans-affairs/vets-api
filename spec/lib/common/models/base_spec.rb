# frozen_string_literal: true

require 'rails_helper'
require 'support/author'

describe Common::Base do
  context 'class methods' do
    subject { Author }

    it 'responds to model_name' do
      expect(subject.model_name.name).to eq('Author')
      expect(subject.model_name.singular).to eq('author')
      expect(subject.model_name.plural).to eq('authors')
    end

    it 'responds to per_page' do
      expect(subject.per_page).to eq(20)
    end

    it 'responds to max_per_page' do
      expect(subject.max_per_page).to eq(1000)
    end

    it 'responds to attribute_set' do
      expect(subject.attribute_set).to be_a(Virtus::AttributeSet)
    end

    it 'responds to sortable_attributes' do
      expect(subject.sortable_attributes)
        .to eq(
          'id' => 'ASC',
          'first_name' => 'ASC',
          'last_name' => 'ASC',
          'birthdate' => 'DESC'
        )
    end

    it 'responds to default_sort' do
      expect(subject.default_sort)
        .to eq('first_name')
    end

    it 'responds to filterable_attributes' do
      expect(subject.filterable_attributes)
        .to eq(
          'id' => %w[eq not_eq],
          'first_name' => %w[eq not_eq match],
          'last_name' => %w[eq not_eq match],
          'birthdate' => %w[eq lteq gteq not_eq]
        )
    end
  end

  context 'instance methods' do
    subject { Author.new(id: '1', first_name: 'Jill', last_name: '', birthdate: '', zipcode: '20001') }

    it 'correctly coerces, nullifying blank' do
      expect(subject.id).to eq(1)
      expect(subject.first_name).to eq('Jill')
      expect(subject.last_name).to eq('')
      expect(subject.birthdate).to be_nil
      expect(subject.zipcode).to eq(20_001)
    end

    it 'responds to attributes, to_h, and, to_hash' do
      expect(subject.attributes).to eq(subject.to_h)
      expect(subject.attributes).to eq(subject.to_hash)
      expect(subject.attributes).to eq(id: 1, first_name: 'Jill', last_name: '', birthdate: nil, zipcode: 20_001)
    end

    it 'identifies if values are changed?' do
      expect(subject.changed?).to be(false)
      expect(subject.changed).to eq([])
      expect(subject.changes).to eq({})
      subject.first_name = 'Jack'
      expect(subject.changed?).to be(true)
      expect(subject.changed).to eq([:first_name])
      expect(subject.changes).to eq(first_name: %w[Jill Jack])
    end
  end
end
