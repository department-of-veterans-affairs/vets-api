# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::NameInput do
  subject { described_class.new(params) }
  let(:params) { attributes_for :name_input }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires a last name' do
      params.delete(:last_name)
      expect(subject).to_not be_valid
    end

    it 'requires a first name' do
      params.delete(:first_name)
      expect(subject).to_not be_valid
    end

    # TODO: bad xsd validation
    # it 'last_name must be less than 16 characters' do
    #   params[:last_name] = 'a' * 16
    #   expect(subject).to_not be_valid
    # end

    # TODO: bad xsd validation
    # it 'first_name must be less than 16 characters' do
    #   params[:first_name] = 'a' * 16
    #   expect(subject).to_not be_valid
    # end

    # TODO: bad xsd validation
    # it 'maiden_name must be less than 16 characters' do
    #   params[:maiden_name] = 'a' * 16
    #   expect(subject).to_not be_valid
    # end

    # TODO: bad xsd validation
    # it 'middle_name must be less than 16 characters' do
    #   params[:middle_name] = 'a' * 16
    #   expect(subject).to_not be_valid
    # end

    it 'suffix must be less than 4 characters' do
      params[:suffix] = 'a' * 4
      expect(subject).to_not be_valid
    end
  end
end
