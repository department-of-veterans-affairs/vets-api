# frozen_string_literal: true

require 'rails_helper'
require 'enrollment/form1095_b/service'

RSpec.describe Enrollment::Form1095B::Service do
  subject(:service) { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:tax_year) { 2023 }
  let(:icn) { '1012667145V762142' }

  describe '#get_form_by_icn' do
    context 'when the request is successful' do
      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform).and_return(
          OpenStruct.new(
            body: {
              'form_data' => {
                'first_name' => 'Jane',
                'last_name' => 'Smith',
                'tax_year' => tax_year,
                'coverage_months' => [true, true, true, true, true, true, true, true, true, true, true, true, true],
                'is_corrected' => false,
                'address' => '456 Elm St',
                'city' => 'Othertown',
                'state' => 'CA',
                'zip_code' => '98765',
                'country' => 'USA'
              },
              'metadata' => {
                'generated_date' => '2023-12-31',
                'submission_status' => 'COMPLETED'
              }
            }
          )
        )
      end

      it 'returns the form data from the enrollment system' do
        response = service.get_form_by_icn(icn: icn, tax_year: tax_year)

        expect(response).to be_a(Hash)
        expect(response['form_data']['tax_year']).to eq(tax_year)
        expect(response['form_data']['first_name']).to eq('Jane')
      end

      it 'makes a request with the correct path' do
        expect_any_instance_of(Common::Client::Base).to receive(:perform).with(
          :get,
          "form1095b/#{tax_year}/icn/#{icn}",
          nil,
          hash_including('X-VA-ICN' => user.icn)
        ).and_return(OpenStruct.new(body: {}))

        service.get_form_by_icn(icn: icn, tax_year: tax_year)
      end

      context 'with monitoring' do
        it 'includes monitoring' do
          expect(service).to receive(:with_monitoring).and_call_original
          service.get_form_by_icn(icn: icn, tax_year: tax_year)
        end
      end
    end

    # Error handling for get_form_by_icn is tested implicitly through get_form tests
    # as they share the same error handling mechanism
  end

  describe 'without a user' do
    let(:user) { nil }
    let(:service_without_user) { described_class.new }

    it 'can still make requests without user headers' do
      allow_any_instance_of(Common::Client::Base).to receive(:perform).with(
        :get,
        "form1095b/#{tax_year}/icn/#{icn}",
        nil,
        {}
      ).and_return(OpenStruct.new(body: {}))

      service_without_user.get_form_by_icn(icn: icn, tax_year: tax_year)
    end
  end
end
