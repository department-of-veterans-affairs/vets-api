# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::ApplicationForm do
  subject { described_class.new(params) }
  let(:params) { attributes_for :application_form }

  context 'with valid attributes' do
    it { expect(subject).to be_valid }

    it 'sending_application is vets.gov by default' do
      expect(subject.sending_application).to eq('vets.gov')
    end

    it 'sent_time is present by default' do
      expect(subject.sent_time.class).to eq(Time)
    end

    it 'generates a 20 character tracking_number' do
      expect(subject.tracking_number.length).to eq(20)
    end
  end

  context 'with invalid attributes' do
    it 'requires an applicant' do
      params.delete(:applicant)
      expect(subject).to_not be_valid
    end

    it 'requires a valid applicant' do
      params[:applicant][:name][:last_name] = nil
      expect(subject).to_not be_valid
    end

    it 'requires a claimant' do
      params.delete(:claimant)
      expect(subject).to_not be_valid
    end

    it 'requires a valid claimant' do
      params[:claimant][:name][:last_name] = nil
      expect(subject).to_not be_valid
    end

    it 'requires a valid currently_buried_persons' do
      params[:currently_buried_persons] = [attributes_for(:currently_buried)]
      params[:currently_buried_persons].first[:name][:last_name] = nil
      expect(subject).to_not be_valid
    end

    it 'requires has_attachments' do
      params.delete(:has_attachments)
      expect(subject).to_not be_valid
    end

    it 'requires has_currently_buried' do
      params.delete(:has_currently_buried)
      expect(subject).to_not be_valid
    end

    it 'has_currently_buried should have a valid format' do
      params[:has_currently_buried] = '8'
      expect(subject).to_not be_valid
    end

    it 'requires a veteran' do
      params.delete(:veteran)
      expect(subject).to_not be_valid
    end

    it 'requires a valid veteran' do
      params[:veteran][:current_name][:last_name] = nil
      expect(subject).to_not be_valid
    end
  end
end
