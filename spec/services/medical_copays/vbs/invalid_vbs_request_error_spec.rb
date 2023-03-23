# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::InvalidVBSRequestError do
  subject { described_class }

  let(:user) { build(:user, :loa3) }
  let(:service) { MedicalCopays::VBS::Service.build(user:) }

  it '#get_copays raises a custom error' do
    allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

    expect { service.get_copays }.to raise_error(MedicalCopays::VBS::InvalidVBSRequestError)
  end

  it '#get_pdf_statement_by_id raises an error' do
    allow_any_instance_of(MedicalCopays::VBS::RequestData).to receive(:valid?).and_return(false)

    expect { service.get_pdf_statement_by_id('123456789') }.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
  end
end
