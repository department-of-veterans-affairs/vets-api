class UpdateIndexOnIvcChampvaForms < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_ivc_champva_forms_on_form_uuid;"
      execute "CREATE INDEX CONCURRENTLY index_ivc_champva_forms_on_form_uuid ON public.ivc_champva_forms USING btree (form_uuid);"
    end
  end

  def down
    safety_assured do
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_ivc_champva_forms_on_form_uuid;"
      execute "CREATE INDEX CONCURRENTLY index_ivc_champva_forms_on_form_uuid ON public.ivc_champva_forms USING btree (form_uuid);"
    end
  end
end
