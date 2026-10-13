-- Ruleaza DUPA ce ai creat utilizatorul nou in Authentication > Users.
-- Inlocuieste UUID_NOU cu UUID-ul REAL.
-- Nu introduce parola aici.
BEGIN;
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_catalog.pg_constraint
 WHERE conrelid='public.zunivo_admins'::regclass AND contype='c' LOOP
  IF pg_catalog.pg_get_constraintdef((SELECT oid FROM pg_catalog.pg_constraint WHERE conrelid='public.zunivo_admins'::regclass AND conname=c.conname)) LIKE '%username%' THEN
   EXECUTE format('ALTER TABLE public.zunivo_admins DROP CONSTRAINT %I',c.conname);
  END IF;
 END LOOP;
END $$;
ALTER TABLE public.zunivo_admins ADD CONSTRAINT zunivo_admin_username_valid CHECK (username ~ '^[a-zA-Z0-9_@.+-]+$');
DELETE FROM public.zunivo_admins WHERE username = 'parausergiu';
-- DECOMENTEAZA urmatoarea linie dupa inlocuirea UUID_NOU:
-- INSERT INTO public.zunivo_admins(user_id,username) VALUES ('UUID_NOU'::uuid,'contactfotoparausergiu@gmail.com') ON CONFLICT (user_id) DO UPDATE SET username=excluded.username;
COMMIT;
