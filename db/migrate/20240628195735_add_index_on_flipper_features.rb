class AddIndexOnFlipperFeatures < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      execute 'CREATE UNIQUE INDEX index_flipper_features_on_key ON public.flipper_features USING btree (key);'
    end
  end
end
