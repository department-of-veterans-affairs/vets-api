# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::UpdateAppointmentForm, type: :model do
  describe 'valid object' do
    subject { described_class.new(status: 'pending') }

    it 'validates presence of required attributes' do
      expect(subject).to be_valid
    end

    it 'params returns expected fields' do
      params = subject.params
      expect(params[:status]).to be('pending')
    end

    it 'json_patch returns expected fields' do
      json_patch = subject.json_patch_op
      expect(json_patch[:op]).to be('replace')
      expect(json_patch[:path]).to be('/status')
      expect(json_patch[:value]).to be('pending')
    end
  end

  describe 'invalid object' do
    subject { described_class.new(status: 'here') }

    it 'validates presence of required attributes' do
      subject.status = nil
      expect(subject).to be_invalid
    end

    it 'validates status values' do
      expect(subject).to be_invalid
    end

    it 'handles invalid status in params' do
      expect { subject.params }.to raise_error(Common::Exceptions::ValidationErrors)
    end

    it 'handles invalid status in json_patch' do
      expect { subject.json_patch_op }.to raise_error(Common::Exceptions::ValidationErrors)
    end
  end
end
