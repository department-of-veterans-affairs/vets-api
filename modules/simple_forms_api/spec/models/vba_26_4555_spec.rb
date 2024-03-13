# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA264555' do
  describe 'veteran middle name' do
    it 'limits the length to 40 characters' do
      middle_name = 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
      warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
      jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
      langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
      wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
      nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum'
      shortened_name = 'Wolfeschlegelsteinhausenbergerdorffwelch'

      form = SimpleFormsApi::VBA264555.new(
        {
          'veteran' => {
            'full_name' => {
              'middle' => middle_name
            }
          }
        }
      )

      expect(shortened_name.length).to eq 40
      expect(form.as_payload[:veteran][:fullName][:middle]).to eq shortened_name
    end
  end
end
