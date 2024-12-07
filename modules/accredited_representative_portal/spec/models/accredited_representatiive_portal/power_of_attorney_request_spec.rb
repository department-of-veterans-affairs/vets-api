# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequest, type: :model do
    describe 'table name' do
      it 'uses custom table name' do
        expect(described_class.table_name).to eq 'ar_power_of_attorney_requests'
      end
    end

    describe 'associations' do
      it 'belongs to latest status update' do
        expect(described_class.new).to belong_to(:latest_status_update)
          .class_name('PowerOfAttorneyRequestStatusUpdate')
          .optional
      end

      it 'has one form' do
        expect(described_class.new).to have_one(:form)
          .class_name('AccreditedRepresentativePortal::PowerOfAttorneyForm')
          .with_foreign_key(:ar_power_of_attorney_request_id)
          .inverse_of(:power_of_attorney_request)
          .dependent(:destroy)
      end
    end
  end
end
