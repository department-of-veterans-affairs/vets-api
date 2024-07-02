# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampvaForm, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_uuid) }

    context 'when form_uuid is missing' do
      it 'is invalid' do
        form = build(:ivc_champva_form, form_uuid: nil)
        expect(form).not_to be_valid
        expect(form.errors[:form_uuid]).to include("can't be blank")
      end
    end
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
