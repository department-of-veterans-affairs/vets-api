# frozen_string_literal: true

require 'rails_helper'
require 'vets/model/pagination'

RSpec.describe 'Vets::Model::Pagination' do
  let(:user_class) do
    Class.new do
      include Vets::Model::Pagination

      attr_accessor :name, :age

      set_pagination per_page: 20, max_per_page: 40
    end
  end

  describe '#per_page' do
    it 'sets the correct per_page value' do
      expect(user_class.per_page).to eq(20)
    end

    it 'defaults to per_page = 10 when no pagination is set' do
      dummy_class = Class.new do
        include Vets::Model::Pagination
      end

      expect(dummy_class.per_page).to eq(10)
    end
  end

  describe '#max_per_page' do
    it 'sets the correct max_per_page value' do
      expect(user_class.max_per_page).to eq(40)
    end

    it 'defaults to max_per_page = 100 when no pagination is set' do
      dummy_class = Class.new do
        include Vets::Model::Pagination
      end

      expect(dummy_class.max_per_page).to eq(100)
    end
  end

  describe '.set_pagination' do
    it 'does not allow calling set_pagination directly from outside the class' do
      expect do
        user_class.set_pagination(per_page: 30, max_per_page: 60)
      end.to raise_error(NoMethodError, /private method `set_pagination' called/)
    end
  end
end
