# frozen_string_literal: true

module VAForms
  module UpdateFormRanking
    module_function

    # rubocop:disable Metrics/MethodLength
    def run
      ActiveRecord::Base.transaction do
        # rubocop:disable Layout/LineLength
        ActiveRecord::Base.connection.execute("
          UPDATE va_forms_forms SET tags ='21-4138F 4138 claim' 	, ranking=1	 WHERE lower(va_forms_forms.form_name)='21-4138';
          UPDATE va_forms_forms SET tags ='21-526ez' 	, ranking=2	 WHERE lower(va_forms_forms.form_name)='21-526ez';
          UPDATE va_forms_forms SET tags ='20-0995' 	, ranking=3	 WHERE lower(va_forms_forms.form_name)='20-0995';
          UPDATE va_forms_forms SET tags ='10-2850c' 	, ranking=4	 WHERE lower(va_forms_forms.form_name)='10-2850c';
          UPDATE va_forms_forms SET tags ='21-2680' 	, ranking=7	 WHERE lower(va_forms_forms.form_name)='21-2680';
          UPDATE va_forms_forms SET tags ='21-686c' 	, ranking=8	 WHERE lower(va_forms_forms.form_name)='21-686c';
          UPDATE va_forms_forms SET tags ='526ez' 	, ranking=10	 WHERE lower(va_forms_forms.form_name)='21-526ez';
          UPDATE va_forms_forms SET tags ='21-22' 	, ranking=11	 WHERE lower(va_forms_forms.form_name)='21-22';
          UPDATE va_forms_forms SET tags ='10-2850a' 	, ranking=12	 WHERE lower(va_forms_forms.form_name)='10-2850a';
          UPDATE va_forms_forms SET tags ='1010 10-10 10-10ez' 	, ranking=13	 WHERE lower(va_forms_forms.form_name)='10-10ez';
          UPDATE va_forms_forms SET tags ='1010 10-10 10-10ez' 	, ranking=48	 WHERE lower(va_forms_forms.form_name)='10-10ez (esp)';
          UPDATE va_forms_forms SET tags ='995' 	, ranking=14	 WHERE lower(va_forms_forms.form_name)='20-0995';
          UPDATE va_forms_forms SET tags ='21-0966' 	, ranking=15	 WHERE lower(va_forms_forms.form_name)='21-0966';
          UPDATE va_forms_forms SET tags ='1258536' 	, ranking=16	 WHERE lower(va_forms_forms.form_name)='1258536';
          UPDATE va_forms_forms SET tags ='21-526' 	, ranking=18	 WHERE lower(va_forms_forms.form_name)='21-526ez';
          UPDATE va_forms_forms SET tags ='10-10172' 	, ranking=19	 WHERE lower(va_forms_forms.form_name)='10-10172';
          UPDATE va_forms_forms SET tags ='21-0845' 	, ranking=20	 WHERE lower(va_forms_forms.form_name)='21-0845';
          UPDATE va_forms_forms SET tags ='21-4142' 	, ranking=21	 WHERE lower(va_forms_forms.form_name)='21-4142';
          UPDATE va_forms_forms SET tags ='20-0996' 	, ranking=22	 WHERE lower(va_forms_forms.form_name)='20-0996';
          UPDATE va_forms_forms SET tags ='21-0781' 	, ranking=23	 WHERE lower(va_forms_forms.form_name)='21-0781';
          UPDATE va_forms_forms SET tags ='21p-534ez' 	, ranking=24	 WHERE lower(va_forms_forms.form_name)='21p-534ez';
          UPDATE va_forms_forms SET tags ='2680' 	, ranking=25	 WHERE lower(va_forms_forms.form_name)='21-2680';
          UPDATE va_forms_forms SET tags ='966' 	, ranking=27	 WHERE lower(va_forms_forms.form_name)='21-0966';
          UPDATE va_forms_forms SET tags ='21p-0969' 	, ranking=28	 WHERE lower(va_forms_forms.form_name)='21p-0969';
          UPDATE va_forms_forms SET tags ='21-8940' 	, ranking=29	 WHERE lower(va_forms_forms.form_name)='21-8940';
          UPDATE va_forms_forms SET tags ='686c' 	, ranking=30	 WHERE lower(va_forms_forms.form_name)='21-686c';
          UPDATE va_forms_forms SET tags ='534' 	, ranking=31	 WHERE lower(va_forms_forms.form_name)='1258536';
          UPDATE va_forms_forms SET tags ='600003' 	, ranking=32	 WHERE lower(va_forms_forms.form_name)='600003';
          UPDATE va_forms_forms SET tags ='10182' 	, ranking=33	 WHERE lower(va_forms_forms.form_name)='va10182';
          UPDATE va_forms_forms SET tags ='845' 	, ranking=34	 WHERE lower(va_forms_forms.form_name)='21-0845';
          UPDATE va_forms_forms SET tags ='21p-530' 	, ranking=35	 WHERE lower(va_forms_forms.form_name)='21p-530';
          UPDATE va_forms_forms SET tags ='4142' 	, ranking=36	 WHERE lower(va_forms_forms.form_name)='21-4142';
          UPDATE va_forms_forms SET tags ='21-674' 	, ranking=37	 WHERE lower(va_forms_forms.form_name)='21-674';
          UPDATE va_forms_forms SET tags ='10-7959c' 	, ranking=38	 WHERE lower(va_forms_forms.form_name)='10-7959c';
          UPDATE va_forms_forms SET tags ='21p-527ez' 	, ranking=39	 WHERE lower(va_forms_forms.form_name)='21p-527ez';
          UPDATE va_forms_forms SET tags ='21-4142a' 	, ranking=40	 WHERE lower(va_forms_forms.form_name)='21-4142a';
          UPDATE va_forms_forms SET tags ='10-5345a' 	, ranking=41	 WHERE lower(va_forms_forms.form_name)='10-5345a';
          UPDATE va_forms_forms SET tags ='26-1880' 	, ranking=42	 WHERE lower(va_forms_forms.form_name)='26-1880';
          UPDATE va_forms_forms SET tags ='22-5490' 	, ranking=43	 WHERE lower(va_forms_forms.form_name)='22-5490';
          UPDATE va_forms_forms SET tags ='1010 10-10 10-10ezr' 	, ranking=44	 WHERE lower(va_forms_forms.form_name)='10-10ezr';
          UPDATE va_forms_forms SET tags ='10-10cg' 	, ranking=45	 WHERE lower(va_forms_forms.form_name)='10-10cg';
          UPDATE va_forms_forms SET tags ='534ez' 	, ranking=46	 WHERE lower(va_forms_forms.form_name)='21p-534ez';
          UPDATE va_forms_forms SET tags ='21p-8416' 	, ranking=47	 WHERE lower(va_forms_forms.form_name)='21p-8416';
          UPDATE va_forms_forms SET tags ='10-10d' 	, ranking=49	 WHERE lower(va_forms_forms.form_name)='10-10d';
          UPDATE va_forms_forms SET tags ='996' 	, ranking=50	 WHERE lower(va_forms_forms.form_name)='20-0996';
          UPDATE va_forms_forms SET tags ='21-4192' 	, ranking=51	 WHERE lower(va_forms_forms.form_name)='21-4192';
          UPDATE va_forms_forms SET tags ='686' 	, ranking=52	 WHERE lower(va_forms_forms.form_name)='21-686c';
          UPDATE va_forms_forms SET tags ='781' 	, ranking=53	 WHERE lower(va_forms_forms.form_name)='21-0781';
          UPDATE va_forms_forms SET tags ='8940' 	, ranking=54	 WHERE lower(va_forms_forms.form_name)='21-8940';
          UPDATE va_forms_forms SET tags ='40-1330' 	, ranking=55	 WHERE lower(va_forms_forms.form_name)='40-1330';
          UPDATE va_forms_forms SET tags ='22-1995' 	, ranking=56	 WHERE lower(va_forms_forms.form_name)='22-1995';
          UPDATE va_forms_forms SET tags ='530' 	, ranking=57	 WHERE lower(va_forms_forms.form_name)='21p-530';
          UPDATE va_forms_forms SET tags ='10-0137' 	, ranking=58	 WHERE lower(va_forms_forms.form_name)='10-0137';
          UPDATE va_forms_forms SET tags ='674' 	, ranking=59	 WHERE lower(va_forms_forms.form_name)='21-674';
          UPDATE va_forms_forms SET tags ='21p-534' 	, ranking=60	 WHERE lower(va_forms_forms.form_name)='21p-534ez';
          UPDATE va_forms_forms SET tags ='5655' 	, ranking=61	 WHERE lower(va_forms_forms.form_name)='va5655';
          UPDATE va_forms_forms SET tags ='21-22a' 	, ranking=62	 WHERE lower(va_forms_forms.form_name)='21-22a';
          UPDATE va_forms_forms SET tags ='21-0779' 	, ranking=63	 WHERE lower(va_forms_forms.form_name)='21-0779';
          UPDATE va_forms_forms SET tags ='2850a' 	, ranking=64	 WHERE lower(va_forms_forms.form_name)='10-2850a';
          UPDATE va_forms_forms SET tags ='21-0538' 	, ranking=65	 WHERE lower(va_forms_forms.form_name)='21-0538';
          UPDATE va_forms_forms SET tags ='of-306' 	, ranking=66	 WHERE lower(va_forms_forms.form_name)='of-306';
          UPDATE va_forms_forms SET tags ='969' 	, ranking=67	 WHERE lower(va_forms_forms.form_name)='21p-0969';
          UPDATE va_forms_forms SET tags ='sf 180' 	, ranking=68	 WHERE lower(va_forms_forms.form_name)='sf180';
          UPDATE va_forms_forms SET tags ='10-8678' 	, ranking=69	 WHERE lower(va_forms_forms.form_name)='10-8678';
          UPDATE va_forms_forms SET tags ='290309 direct deposit' 	, ranking=1	 WHERE lower(va_forms_forms.form_name)='29-0309';
          UPDATE va_forms_forms SET tags= '20572 direct deposit' 	, ranking=2	 WHERE lower(va_forms_forms.form_name)='20-572';
          UPDATE va_forms_forms SET tags= 'SF1199a direct deposit' 	, ranking=3 WHERE lower(va_forms_forms.form_name)='sf-1199a';
          UPDATE va_forms_forms SET tags= '100459 release of information authorization' 	, ranking=3 WHERE lower(va_forms_forms.form_name)='10-0459';
          UPDATE va_forms_forms SET tags= '0710 release of information authorization' 	, ranking=1 WHERE lower(va_forms_forms.form_name)='va0710';
          UPDATE va_forms_forms SET tags= '10252 health release of information authorization' 	, ranking=2 WHERE lower(va_forms_forms.form_name)='10-252';
          UPDATE va_forms_forms SET tags= '100094f health' 	, ranking=2 WHERE lower(va_forms_forms.form_name)='10-0094f';
          UPDATE va_forms_forms SET tags= 'supplemental claim' 	, ranking=14 WHERE lower(va_forms_forms.form_name)='20-0995';
          UPDATE va_forms_forms SET tags= 'advance directive'  WHERE lower(va_forms_forms.form_name)='10-0137';
          UPDATE va_forms_forms SET tags= 'advance directive'  WHERE lower(va_forms_forms.form_name)='10-0137a';
          UPDATE va_forms_forms SET tags= 'associated health occupations'  WHERE lower(va_forms_forms.form_name)='10-2850c';
          UPDATE va_forms_forms SET tags= 'appeal appeal', ranking = 1  WHERE lower(va_forms_forms.form_name)='20-0995';
          UPDATE va_forms_forms SET tags= 'appeal appeal', ranking = 2  WHERE lower(va_forms_forms.form_name)='22-0996';
          UPDATE va_forms_forms SET tags= 'assign a representative appeal', ranking= 4 WHERE lower(va_forms_forms.form_name)='21-22';
          UPDATE va_forms_forms SET tags= 'assign a representative appeal', ranking = 5  WHERE lower(va_forms_forms.form_name)='21-22a';
          UPDATE va_forms_forms SET tags ='appeal va10182' 	, ranking=3	 WHERE lower(va_forms_forms.form_name)='va10182';
          UPDATE va_forms_forms SET tags ='appeal' 	, ranking=6	 WHERE lower(va_forms_forms.form_name)='20-0998';
      ")
        # rubocop:enable Layout/LineLength
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end

namespace :va_forms do
  task update_form_ranking: :environment do
    VAForms::UpdateFormRanking.run
  end
end
