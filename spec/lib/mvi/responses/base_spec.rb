# frozen_string_literal: true
require 'rails_helper'
require 'mvi/responses/find_candidate'
require "#{Rails.root}/spec/support/mvi/mvi_response"

describe MVI::Responses::Base do
  let(:klass) do
    Class.new(MVI::Responses::Base) do
      mvi_endpoint :my_endpoint
    end
  end
  let(:savon_response) do
    double('Savon::Response')
  end
  let(:body) do
    {
      my_endpoint: {
        acknowledgement: {
          type_code: {
            :@code => 'AA'
          }
        },
        control_act_process: {
          query_by_parameter: {
            query_id: {
              :@extension => '18204',
              :@root => '2.16.840.1.113883.3.933'
            },
            status_code: {
              :@code => 'new'
            },
            modify_code: {
              :@code => 'MVI.COMP1'
            },
            initial_quantity: {
              :@value => '1'
            },
            parameter_list: {
              living_subject_name: {
                value: {
                  given: %w(John William),
                  family: 'Smith',
                  :@use => 'L'
                },
                semantics_text: 'LivingSubject.name'
              }
            }
          }
        }
      }
    }
  end
  let(:xml) { '<xml><some_tags/></xml>' }

  describe '#intialize' do
    it 'should be initialized with the correct attrs' do
      allow(savon_response).to receive(:body) { body }
      allow(savon_response).to receive(:xml) { xml }
      response = klass.new(savon_response)

      expect(response.code).to eq('AA')
      expect(response.query).to eq(body.dig(:my_endpoint, :control_act_process, :query_by_parameter))
      expect(response.original_response).to eq('<xml><some_tags/></xml>')
    end
  end

  describe '#body' do
    it 'should invoke the subclass body' do
      allow(savon_response).to receive(:body) { body }
      allow(savon_response).to receive(:xml) { xml }
      response = klass.new(savon_response)

      expect { response.body }.to raise_error(MVI::Responses::NotImplementedError)
    end
  end
end
