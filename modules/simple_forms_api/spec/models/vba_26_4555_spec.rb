# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA264555' do
  describe 'veteran name' do
    it 'limits the length to 30 characters' do
      name = 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
      warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
      jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
      langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
      wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
      nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum'
      shortened_name = 'Wolfeschlegelsteinhausenberger'

      form = SimpleFormsApi::VBA264555.new(
        {
          'veteran' => {
            'full_name' => {
              'first' => name,
              'middle' => name,
              'last' => name
            }
          }
        }
      )

      expect(shortened_name.length).to eq 30
      expect(form.as_payload[:veteran][:fullName][:first]).to eq shortened_name
      expect(form.as_payload[:veteran][:fullName][:middle]).to eq shortened_name
      expect(form.as_payload[:veteran][:fullName][:last]).to eq shortened_name
    end
  end
end
