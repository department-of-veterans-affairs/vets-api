# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::MilitaryRankInput do
  context 'with valid attributes' do
    subject { described_class.new(params) }
    let(:params) do
      { branch_of_service: 'AF', start_date: '1947-09-18T00:00:00-04:00', end_date: '1947-09-18T00:00:00-04:00' }
    end

    context 'with valid attributes' do
      it { expect(subject).to be_valid }
    end

    context 'with invalid attributes' do
      it 'requires a branch_of_service' do
        params.delete(:branch_of_service)
        expect(subject).not_to be_valid
      end

      it 'requires a 2 character long branch_of_service' do
        params[:branch_of_service] = 'A'
        expect(subject).not_to be_valid
      end

      it 'requires a start_date' do
        params.delete(:start_date)
        expect(subject).not_to be_valid
      end

      it 'requires a valid ISO 8601 start_date string' do
        params[:start_date] = '1947-99'
        expect(subject).not_to be_valid
      end

      it 'requires a end_date' do
        params.delete(:end_date)
        expect(subject).not_to be_valid
      end

      it 'requires a valid ISO 8601 end_date string' do
        params[:end_date] = '1947-99'
        expect(subject).not_to be_valid
      end
    end
  end
end
