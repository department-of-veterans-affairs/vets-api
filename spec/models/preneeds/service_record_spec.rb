# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::ServiceRecord do
  subject { described_class.new(params) }
  let(:params) { attributes_for :service_record }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }
  end

  context 'with invalid attributes' do
    it 'requires a branch_of_service' do
      params.delete(:branch_of_service)
      expect(subject).to_not be_valid
    end

    it 'requires a 2 character branch_of_service' do
      params[:branch_of_service] = 'A'
      expect(subject).to_not be_valid
    end

    it 'requires a discharge_type' do
      params.delete(:discharge_type)
      expect(subject).to_not be_valid
    end

    it 'requires a discharge_type between 1 and 7' do
      params[:discharge_type] = '100'
      expect(subject).to_not be_valid
    end

    it 'requires a properly formated entered_on_duty_date' do
      params[:entered_on_duty_date] = '11/11/11'
      expect(subject).to_not be_valid
    end

    it 'requires a properly formatted national_guard_state' do
      params[:national_guard_state] = 'AAAA'
      expect(subject).to_not be_valid
    end

    it 'requires a properly formated release_from_duty_date' do
      params[:release_from_duty_date] = '11/11/11'
      expect(subject).to_not be_valid
    end
  end
end
