# frozen_string_literal: true

require 'rails_helper'
require 'form_transformers/benefits_discovery/health_care_application_transformer'

RSpec.describe FormTransformers::BenefitsDiscovery::HealthCareApplicationTransformer do
  subject do
    FormTransformers::BenefitsDiscovery::HealthCareApplicationTransformer.new(form)
  end

  let(:form) do
    Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json').read
  end

  it 'formats param values from form json' do
    expect(subject.transform).to eq({
                                      dateOfBirth: '1923-01-02',
                                      disabilityRating: 60,
                                      serviceDates: [{
                                        startDate: '1980-03-07',
                                        endDate: '1984-07-08',
                                        dischargeStatus: 'GENERAL',
                                        branchOfService: 'MERCHANT SEAMAN'
                                      }]
                                    })
  end
end
