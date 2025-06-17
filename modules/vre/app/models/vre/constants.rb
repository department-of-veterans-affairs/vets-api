# frozen_string_literal: true

module VRE
  class Constants
    FORM = '28-1900'
    # We will be adding numbers here and eventually completeley removing this and the caller to open up VRE submissions
    # to all vets
    PERMITTED_OFFICE_LOCATIONS = %w[].freeze

    REGIONAL_OFFICE_EMAILS = {
      '301' => 'VRC.VBABOS@va.gov',
      '304' => 'VRE.VBAPRO@va.gov',
      '306' => 'VRE.VBANYN@va.gov',
      '307' => 'VRC.VBABUF@va.gov',
      '308' => 'VRE.VBAHAR@va.gov',
      '309' => 'vre.vbanew@va.gov',
      '310' => 'VREBDD.VBAPHI@va.gov',
      '311' => 'VRE.VBAPIT@va.gov',
      '313' => 'VRE.VBABAL@va.gov',
      '314' => 'VRE.VBAROA@va.gov',
      '315' => 'VRE.VBAHUN@va.gov',
      '316' => 'VRETMP.VBAATG@va.gov',
      '317' => 'VRE281900.VBASPT@va.gov',
      '318' => 'VRC.VBAWIN@va.gov',
      '319' => 'VRC.VBACMS@va.gov',
      '320' => 'VREAPPS.VBANAS@va.gov',
      '321' => 'VRC.VBANOL@va.gov',
      '322' => 'VRE.VBAMGY@va.gov',
      '323' => 'VRE.VBAJAC@va.gov',
      '325' => 'VRE.VBACLE@va.gov',
      '326' => 'VRE.VBAIND@va.gov',
      '327' => 'VRE.VBALOU@va.gov',
      '328' => 'VAVBACHI.VRE@va.gov',
      '329' => 'VRE.VBADET@va.gov',
      '330' => 'VREApplications.VBAMIW@va.gov',
      '331' => 'VRC.VBASTL@va.gov',
      '333' => 'VRE.VBADES@va.gov',
      '334' => 'VRE.VBALIN@va.gov',
      '335' => 'VRC.VBASPL@va.gov',
      '339' => 'VRE.VBADEN@va.gov',
      '340' => 'VRC.VBAALB@va.gov',
      '341' => 'VRE.VBASLC@va.gov',
      '343' => 'VRC.VBAOAK@va.gov',
      '344' => 'ROVRC.VBALAN@va.gov',
      '345' => 'VRE.VBAPHO@va.gov',
      '346' => 'VRE.VBASEA@va.gov',
      '347' => 'VRE.VBABOI@va.gov',
      '348' => 'VRE.VBAPOR@va.gov',
      '349' => 'VREAPPS.VBAWAC@va.gov',
      '350' => 'VRE.VBALIT@va.gov',
      '351' => 'VREBDD.VBAMUS@va.gov',
      '354' => 'VRE.VBAREN@va.gov',
      '355' => 'MBVRE.VBASAJ@va.gov',
      '358' => 'VRE.VBAMPI@va.gov',
      '362' => 'VRE.VBAHOU@va.gov',
      '372' => 'VRE.VBAWAS@va.gov',
      '373' => 'VRE.VBAMAN@va.gov',
      '377' => 'EBENAPPS.VBASDC@va.gov',
      '402' => 'VRE.VBATOG@va.gov',
      '405' => 'VRE.VBAMAN@va.gov',
      '436' => 'VRC.VBAFHM@va.gov',
      '437' => 'VRC.VBAFAR@va.gov',
      '438' => 'VRC.VBAFAR@va.gov',
      '442' => 'VRE.VBADEN@va.gov',
      '452' => 'VRE.VBAWIC@va.gov',
      '459' => 'VRC.VBAHON@va.gov',
      '460' => 'VAVBA/WIM/RO/VR&E@vba.va.gov',
      '463' => 'VRE.VBAANC@va.gov',
      '000' => 'VRE.VBAPIT@va.gov'
    }.freeze
  end
end
