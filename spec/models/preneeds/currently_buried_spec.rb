# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::CurrentlyBuried do
  subject { described_class.new(params) }
  let(:params) { attributes_for :currently_buried }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires a name' do
      params.delete(:name)
      expect(subject).to_not be_valid
    end

    it 'requires a valid name' do
      params[:name][:last_name] = nil
      expect(subject).to_not be_valid
    end

    it 'requires a properly formatted cemetery_number' do
      params[:cemetery_number] = 'A1!'
      expect(subject).to_not be_valid
    end
  end
end
