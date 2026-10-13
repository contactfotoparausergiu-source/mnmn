ZUNIVO V8 — INFINITYFREE + SUPABASE

NOU:
- Verified: insignă bazată pe verificare manuală, înscrisă EXCLUSIV de administrator în Supabase SQL Editor; nu există încă panou de verificare sau încărcare documente.
- Compare: comparație de 2–3 prestatori și prețuri declarate.
- Flash: afișează ofertele Econom active, cu data expirării; nu este o promoție separată.
- Local: filtrează după județ/localitate/categorie, fără geolocalizare ori calcul de distanță.
- Budget: buget local în browser (localStorage), fără sincronizare online.
- Meet: solicitări și acceptări cu link HTTPS, fără videoconferință integrată și fără notificări email.
- Rewards: cod de recomandare și înregistrarea unei recomandări per client, fără recompense automate.

PĂSTRATE: toate paginile și funcțiile V7, V6, V5 (Match, cereri, SOS, recenzii, Duo, Guest, Econom, Asistent, Progress, Radar, Backup etc.). Regizorul Evenimentului rămâne eliminat.

INSTALARE PE INFINITYFREE:
1. FĂ BACKUP la fișiere și la baza de date Supabase înainte de upgrade.
2. Dacă ai deja V7, execută DOAR secțiunea '-- ZUNIVO V8' din supabase.sql în Supabase SQL Editor. La instalare nouă, execută întregul fișier în ordine.
3. Completează config.js cu URL-ul și cheia PUBLICABILĂ/anon Supabase, NICIODATĂ cheia service_role.
4. Încarcă prin FileZilla în htdocs toate fișierele HTML/CSS/JS din pachet, fără supabase.sql sau README.txt.
5. Setează Authentication > URL Configuration în Supabase cu URL-ul site-ului InfinityFree.
6. Testează cu două conturi de prestator și două de client: login, profiluri, recenzii, Meet, cod recomandare, comparații.
7. Verificarea prestatorilor se face manual prin SQL după verificarea reală a informațiilor lor.

IMPORTANT: Versiune de dezvoltare; testarea live pe InfinityFree și Supabase nu a fost efectuată. Nu există plăți integrate, verificare automată de identitate, recompense acordate sau notificări automate. Respectă GDPR și obține acordul persoanelor înainte de publicarea datelor personale.

MENIU DROPDOWN: toate paginile folosesc meniul grupat; incarca si dropdown.js in htdocs.


ZUNIVO V9 — INVITE, INSIGHTS, NOTIFY, TEAM
- Invite: clientul creează pagini cu link secret; invitații confirmă RSVP fără cont. Răspunsurile sunt vizibile doar organizatorului. Linkul este un token de acces: trimite-l doar persoanelor dorite. Fără protecție CAPTCHA/rate-limit integrată; pentru trafic mare configurează protecții externe.
- Insights: vizualizări aproximative (o vizită/browser/zi), număr servicii și oferte trimise. Statisticile nu sunt anti-fraudă. Membrii echipei au doar citire.
- Notify: notificări în cont pentru cereri Meet, răspunsuri Meet, oferte noi și modificări de status. Fără email, push, alerte pentru toate modulele sau actualizare în timp real: reîncarcă pagina.
- Team: proprietarul generează un cod valabil 7 zile; colaboratorul autentificat îl folosește o singură dată. Accesul este doar la Insights, nu la editarea profilului, cereri sau plăți. Proprietarul poate revoca accesul.
INSTALARE: fă backup. Dacă ai deja V8 dropdown, rulează DOAR secțiunea '-- ZUNIVO V9' din supabase.sql în Supabase SQL Editor. La instalare nouă rulează întregul supabase.sql în ordine. Încarcă în htdocs fișierele HTML/CSS/JS, NU încărca supabase.sql ori README.txt. Configurează config.js cu cheia anon/publishable, NICIODATĂ service_role. Testează cu conturi de client, prestator și invitat neautentificat.
Limitări: nu a fost testat live pe Supabase sau InfinityFree. Funcționalitățile anterioare sunt păstrate; dropdown-ul este păstrat.

ZUNIVO V10 — CLIENT RATING
- Prestatorii pot evalua clientii numai pentru oferte cu status confirmed. O evaluare per oferta, editabila si stergibila.
- Clientii isi pot vedea propriile evaluari; acestea NU sunt publice.
- Pentru upgrade de la V9 ruleaza doar sectiunea -- ZUNIVO V10 din supabase.sql in Supabase SQL Editor.
- Incarca HTML/CSS/JS in htdocs, inclusiv client-reviews.html si v10.js. NU publica SQL sau README.
- Fara testare live pe Supabase / InfinityFree; testeaza cu doua conturi si o oferta confirmata.


ZUNIVO V11 — ADMIN
- Execută doar secțiunea ZUNIVO V11 din supabase.sql dacă ai deja V10.
- Creează un utilizator în Supabase Dashboard > Authentication > Users cu email privat și o parolă puternică, unică.
- Adaugă drepturile prin SQL Editor: DELETE FROM public.zunivo_admins WHERE username = 'parausergiu';
  INSERT INTO public.zunivo_admins(user_id,username) VALUES ('UUID-UL-CONTULUI'::uuid,'contactfotoparausergiu@gmail.com');
- Accesează admin.html sau tastează Alt+Shift+A (Windows), Option+Shift+A (Mac).
- Conectarea se face cu email + parolă Supabase Auth; numele de administrator este contactfotoparausergiu@gmail.com în baza de date.
- Parola nu este inclusă în cod sau în SQL. NU utiliza parola scurtă comunicată în chat; setează una nouă și unică.
- Panoul gestionează cele 23 de tabele publice Zunivo prin RPC protejat, cu jurnal de audit. Nu gestionează direct utilizatorii Supabase Auth, cheile, storage, configurarea serverului sau toate politicile RLS.
- Folosește editorul JSON cu grijă. Nu există coș de reciclare. Fă backup înainte de modificări.
- Scurtătura NU este un mecanism de securitate. Verificarea autorizării are loc în Supabase.
- Nu publica fișierul supabase.sql în htdocs.

ZUNIVO V12 - RESTAURANTE
1. Dacă ai V11, execută numai secțiunea ZUNIVO V12 din supabase.sql în Supabase SQL Editor.
2. Încarcă HTML/CSS/JS în htdocs; nu publica supabase.sql sau README.
3. Restaurantul se înscrie ca prestator și selectează categoria Restaurante & săli de evenimente în Contul meu.
4. Completează capacitatea, adresa, tarifele per persoană, chiria, meniurile și facilitățile.
5. Folosește + Adaugă serviciu pentru pachete individuale și prețuri.
6. Datele sunt publice în profil; modificarea lor este limitată prin RLS la proprietar.
7. Nu include rezervări automate de mese sau verificarea disponibilității sălilor.

IMPORTANT: Parola nu este stocata in site. Creeaza utilizatorul in Supabase Authentication > Users, apoi foloseste UUID-ul lui pentru asocierea drepturilor de admin. Sterge vechiul utilizator Auth numai dupa verificarea accesului nou.
