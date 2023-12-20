# frozen_string_literal: true

module HCA
  class OverridesParser
    STATE_OVERRIDES = {
      'MEX' => {
        'aguascalientes' => 'AGS.',
        'baja-california-norte' => 'B.C.',
        'baja-california-sur' => 'B.C.S.',
        'campeche' => 'CAM.',
        'chiapas' => 'CHIS.',
        'chihuahua' => 'CHIH.',
        'coahuila' => 'COAH.',
        'colima' => 'COL.',
        'distrito-federal' => 'D.F.',
        'durango' => 'DGO.',
        'guanajuato' => 'GTO.',
        'guerrero' => 'GRO.',
        'hidalgo' => 'HGO.',
        'jalisco' => 'JAL.',
        'mexico' => 'MEX.',
        'michoacan' => 'MICH.',
        'morelos' => 'MOR.',
        'nayarit' => 'NAY.',
        'nuevo-leon' => 'N.L.',
        'oaxaca' => 'OAX.',
        'puebla' => 'PUE.',
        'queretaro' => 'QRO.',
        'quintana-roo' => 'Q.ROO.',
        'san-luis-potosi' => 'S.L.P.',
        'sinaloa' => 'SIN.',
        'sonora' => 'SON.',
        'tabasco' => 'TAB.',
        'tamaulipas' => 'TAMPS.',
        'tlaxcala' => 'TLAX.',
        'veracruz' => 'VER.',
        'yucatan' => 'YUC.',
        'zacatecas' => 'ZAC.'
      }
    }.freeze

    attr_accessor :params, :form

    def initialize(form)
      @form = form
    end

    def override
      override_address_states

      form
    end

    def override_address_states
      %w[veteranHomeAddress veteranAddress spouseAddress veteranContacts].each do |target|
        # For 'veteranContacts', we need to loop through each entry and override any necessary state/country fields
        if target == 'veteranContacts'
          form.dig(target).each do |contact|
            override_individual_address(contact, 'address')
          end
        else
          override_individual_address(form, target)
        end
      end
    end

    # @param [Hash] data that contains address fields
    def override_individual_address(data, key)
      country = data.dig(key, 'country')
      state = data.dig(key, 'state')

      return unless STATE_OVERRIDES.key?(country)
      return unless STATE_OVERRIDES[country]&.key?(state)

      data[key]['state'] = STATE_OVERRIDES[country][state]
    end
  end
end
