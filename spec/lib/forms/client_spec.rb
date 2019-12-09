# frozen_string_literal: true

require 'rails_helper'

describe Forms::Client do
  subject { described_class.new(query) }

  let(:query) { nil }

  describe '#get_all' do
    context 'with no query' do
      let(:query) { nil }

      it 'returns a form response object' do
        VCR.use_cassette('forms/200_all_forms') do
          response = subject.get_all
          expect(response).to be_a Forms::Responses::Response
        end
      end
    end

    context 'with a query' do
      let(:query) { 'health' }

      it 'returns a form response object' do
        VCR.use_cassette('forms/200_form_query') do
          response = subject.get_all
          expect(response).to be_a Forms::Responses::Response
        end
      end
    end
  end
end
