ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.connection.execute <<-SQL
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'crc32') THEN
        CREATE OR REPLACE FUNCTION crc32(data bytea) RETURNS bigint AS $$
        DECLARE
            crc bigint := 0xFFFFFFFF;
            i integer;
            j integer;
            byte integer;
        BEGIN
            FOR i IN 0..length(data)-1 LOOP
                byte := get_byte(data, i);
                crc := crc # byte;
                FOR j IN 0..7 LOOP
                    IF crc & 1 = 1 THEN
                        crc := (crc >> 1) # 0xEDB88320;
                    ELSE
                        crc := crc >> 1;
                    END IF;
                END LOOP;
            END LOOP;
            RETURN ~crc & 0xFFFFFFFF;  -- Ensure the result is treated as an unsigned 32-bit integer
        END;
        $$ LANGUAGE plpgsql IMMUTABLE;
      END IF;
    END
    $$;
  SQL
end
