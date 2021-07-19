# frozen_string_literal: true

require 'rails_helper'
require 'vbs/requests/list_statements'
require_relative './vbs_request_model_shared_example'

describe VBS::Requests::ListStatements do
  it 'inherits from VBS::Requests::Base' do
    expect(described_class.ancestors).to include(VBS::Requests::Base)
  end

  it_behaves_like 'a VBS request model'
end
