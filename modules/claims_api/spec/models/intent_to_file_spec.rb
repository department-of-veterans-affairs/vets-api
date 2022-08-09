# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::IntentToFile, type: :model do
  describe 'requiring fields' do
    context "when 'status' is not provided" do
      it 'fails validation' do
        itf = ClaimsApi::IntentToFile.new(cid: 'helloworld')

        expect { itf.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when 'cid' is not provided" do
      it 'fails validation' do
        itf = ClaimsApi::IntentToFile.new(status: 'submitted')

        expect { itf.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when all required attributes are provided' do
      it 'saves the record' do
        itf = ClaimsApi::IntentToFile.new(status: 'submitted', cid: 'helloworld')

        expect { itf.save! }.not_to raise_error
      end
    end
  end
end
