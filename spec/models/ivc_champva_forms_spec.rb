# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampvaForm, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
  end

  describe 'factory' do
    it 'is valid' do
      expect(build(:ivc_champva_form)).to be_valid
    end
  end

  describe 'methods' do
    describe '#create' do
      it 'creates a new form' do
        expect { create(:ivc_champva_form) }.to change(IvcChampvaForm, :count).by(1)
      end
    end

    describe '#update' do
      let(:form) { create(:ivc_champva_form) }

      it 'updates an existing form' do
        new_email = 'new_email@example.com'
        form.update(email: new_email)
        expect(form.reload.email).to eq(new_email)
      end
    end

    describe '#destroy' do
      let!(:form) { create(:ivc_champva_form) }

      it 'deletes an existing form' do
        expect { form.destroy }.to change(IvcChampvaForm, :count).by(-1)
      end
    end
  end
end
