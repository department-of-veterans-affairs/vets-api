# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class AddressInput < Common::Base
    include ActiveModel::Validations

    COUNTRY_CODES = %w(
      AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ
      BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV BR IO BN BG BF BI KH
      CM CA CV KY CF TD CL CN CX CC CO KM CG CD CK CR CI HR CU CW CY CZ
      DK DJ DM DO
      EC EG SV GQ ER EE ET
      FK FO FJ FI FR
      GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY
      HT HM VA HN HK HU
      IS IN ID IR IQ IE IM IL IT
      JM JP JE JO
      KZ KE KI KP KR KW KG
      LA LV LB LS LR LY LI LT LU
      MO MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM
      NA NR NP NL NC NZ NI NE NG NU NF MP NO
      OM
      PK PW PS PA PG PY PE PH PN PL PT PR
      QA
      RE RO RU RW
      BL SH KN LC MF PM VC WS SM ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK SD SR SJ SZ SE CH SY
      TW TJ TZ TH TL TG TK TO TT TN TR TM TC TV
      UG UA AE GB US UM UY UZ
      VU VE VN VG VI
      WF EH
      YE
      ZM ZW
    ).freeze

    # Length validations on address becuase of bad xsd validation
    validates :address1, presence: true
    validates :address1, :address2, :address3, length: { maximum: 35 }
    validates :city, length: { maximum: 30 }, presence: true
    validates :country_code, inclusion: { in: COUNTRY_CODES }, presence: true
    validates :postal_zip, length: { is: 5 }, presence: true
    validates :state, length: { minimum: 2, maximum: 3 }, presence: true

    attribute :address1, String
    attribute :address2, String
    attribute :address3, String
    attribute :city, String
    attribute :country_code, String
    attribute :postal_zip, String
    attribute :state, String

    def message
      hash = {
        address1: address1, address2: address2, address3: address3, city: city,
        country_code: country_code, postal_zip: postal_zip, state: state
      }

      [:address2, :address3].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end
  end
end
