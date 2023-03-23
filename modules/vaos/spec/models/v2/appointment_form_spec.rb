# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentForm, type: :model do
  let(:user) { build(:user, :vaos) }

  describe 'valid object' do
    subject { build(:appointment_form_v2, :community_cares, user:) }

    it 'validates presence of required attributes' do
      expect(subject).to be_valid
    end

    it 'params returns expected fields' do
      params = subject.params
      expect(params[:kind]).to be('cc')
      expect(params[:status]).to be('proposed')
      expect(params[:location_id]).to be('983')
      expect(params[:contact]).to be_a(Hash)
      expect(params[:service_type]).to be('podiatry')
      expect(params[:requested_periods]).to be_a(Array)
    end
  end

  describe 'with empty slot hash' do
    subject { build(:appointment_form_v2, :with_empty_slot_hash, user:) }

    it 'validates presence of required attributes' do
      expect(subject).to be_valid
    end

    it 'drops empty slot hash' do
      params = subject.params
      expect(params.key?('slot')).to be(false)
    end
  end
end
