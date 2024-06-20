# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PdfGenerator2122Controller', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122' }

    # context 'when submitting all required data' do
    #   let(:all_required_params) do
    #     {
    #       veteran_address_line1: '123 Fake St.',
    #       flags: [{ flag_type: 'email', flagged_value: 'example@email.com' }]
    #     }
    #   end

    #   it 'responds with a created status' do
    #     post base_path, params: all_required_params
    #     expect(response).to have_http_status(:created)
    #   end
    # end

    context 'when submitting incomplete data' do
      let(:incomplete_params) do
        {
          veteran_address_line1: '123 Fake St.',
          consent_limits: %w[limit1 limit2]
        }
      end

      it 'responds with an unprocessable entity status' do
         post base_path, params: incomplete_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
