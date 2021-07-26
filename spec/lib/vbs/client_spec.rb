# frozen_string_literal: true

require 'rails_helper'
require 'vbs/client'

describe VBS::Client do
  let(:vbs_request) { double(http_method: :post, path: '/books', data: {}) }
  let(:vbs_request_validation_error) { StandardError.new('VBS Request Validarion Error') }
  let(:vbs_reponse) { double('VBS response') }

  def expect_perform_to_be_called!
    expect(subject).to receive(:perform).with( # rubocop:disable RSpec/SubjectStub
      vbs_request.http_method,
      vbs_request.path,
      vbs_request.data
    ).and_return(vbs_reponse)
  end

  describe '#exec' do
    context 'when validating request' do
      context 'when request is not valid' do
        let(:error) { vbs_request_validation_error }

        before do
          expect(vbs_request).to receive(:validate!).and_raise(vbs_request_validation_error)
        end

        it 'raises an error' do
          expect { subject.exec(vbs_request) }.to raise_error(vbs_request_validation_error)
        end
      end

      context 'when request is valid' do
        before do
          expect(vbs_request).to receive(:validate!).and_return(vbs_request)
          expect_perform_to_be_called!
        end

        it 'calls #perform with the provided request' do
          expect(subject.exec(vbs_request)).to eq(vbs_reponse)
        end
      end
    end

    context 'when skipping validation' do
      context 'when request is not valid' do
        before do
          expect(vbs_request).not_to receive(:validate!)
          expect_perform_to_be_called!
        end

        it 'calls perform with the provided request' do
          expect(subject.exec(vbs_request, skip_request_validation: true)).to eq(vbs_reponse)
        end
      end

      context 'when request is valid' do
        before do
          expect(vbs_request).not_to receive(:validate!)
          expect_perform_to_be_called!
        end

        it 'calls #perform with the provided request' do
          expect(subject.exec(vbs_request, skip_request_validation: true)).to eq(vbs_reponse)
        end
      end
    end
  end
end
