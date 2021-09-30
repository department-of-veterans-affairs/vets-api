# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::IntentToFile, type: :model do
  describe "'active?'" do
    let(:attributes) do
      {
        id: '1',
        creation_date: creation_date,
        expiration_date: expiration_date,
        status: status,
        type: 'compensation'
      }
    end
    let(:creation_date) { Time.zone.now.to_date }
    let(:expiration_date) { Time.zone.now.to_date + 1.year }

    context "when 'status' is not active" do
      let(:status) { 'inactive' }

      it 'is not active' do
        itf = ClaimsApi::IntentToFile.new(attributes)
        expect(itf.active?).to be false
      end
    end

    context "when 'status' is active" do
      let(:status) { 'active' }

      context 'but itf is expired' do
        let(:creation_date) { Time.zone.now.to_date - 1.year }
        let(:expiration_date) { Time.zone.now.to_date }

        it 'is not active' do
          itf = ClaimsApi::IntentToFile.new(attributes)
          expect(itf.active?).to be false
        end
      end

      context 'and itf is not expired' do
        let(:creation_date) { Time.zone.now.to_date }
        let(:expiration_date) { Time.zone.now.to_date + 1.year }

        it 'is active' do
          itf = ClaimsApi::IntentToFile.new(attributes)
          expect(itf.active?).to be true
        end
      end
    end
  end
end
