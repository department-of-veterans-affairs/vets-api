# frozen_string_literal: true

RSpec.shared_examples 'shared pdf constructor base behavior' do
  it 'select none of the boxes when nothing is added on the form' do
    result = pdf_constructor_instance.send(:set_limitation_of_consent_check_box, nil, 'DRUG_ABUSE')
    expect(result).to eq(0)
  end

  it 'does not select the box for an added consent limit' do
    result = pdf_constructor_instance.send(:set_limitation_of_consent_check_box, ['HIV'], 'HIV')
    expect(result).to eq(0)
  end
end
