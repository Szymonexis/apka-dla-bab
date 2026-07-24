#!/bin/bash
# Test dymny API Ogarniaczki - można odpalać wielokrotnie (losowe e-maile).
# Użycie: BASE_URL=http://localhost:8080 NTFY_URL=http://localhost:8090 ./smoke.sh
# Sekcja push wykonuje się tylko, gdy serwer ntfy odpowiada pod NTFY_URL.
# DISPATCH_WAIT (domyślnie 35 s) musi być większy niż DISPATCH_INTERVAL_SECONDS backendu.
set -e
SUFFIX=$RANDOM$RANDOM
B=${BASE_URL:-http://localhost:8080}
N=${NTFY_URL:-http://localhost:8090}
WAIT=${DISPATCH_WAIT:-35}
PASS=0; FAIL=0
check() { # check <nazwa> <oczekiwany_status> <faktyczny_status>
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "OK   $1 ($3)";
  else FAIL=$((FAIL+1)); echo "FAIL $1 (oczekiwano $2, jest $3)"; fi
}
jqget() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }

# --- rejestracja i logowanie ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/auth/register -d '{"email":"kasia+'$SUFFIX'@test.pl","password":"sekret123","displayName":"Kasia"}')
check "rejestracja" 201 "$(tail -1 <<<"$R")"
TOKEN=$(head -1 <<<"$R" | jqget "['token']")
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/auth/register -d '{"email":"kasia+'$SUFFIX'@test.pl","password":"sekret123"}')
check "duplikat emaila -> 409" 409 "$R"
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/auth/login -d '{"email":"kasia+'$SUFFIX'@test.pl","password":"zle"}')
check "złe hasło -> 401" 401 "$R"
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/auth/login -d '{"email":"kasia+'$SUFFIX'@test.pl","password":"sekret123"}')
check "logowanie" 200 "$(tail -1 <<<"$R")"
A="Authorization: Bearer $TOKEN"
R=$(curl -s -o /dev/null -w '%{http_code}' $B/api/me)
check "brak tokenu -> 401" 401 "$R"
R=$(curl -s -H "$A" $B/api/me | jqget "['displayName']")
[ "$R" = "Kasia" ] && check "GET /me" ok ok || check "GET /me" Kasia "$R"

# --- notatki ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/notes -H "$A" -d '{"title":"Zakupy","content":"mleko, chleb, masło","pinned":true}')
check "notatka: create" 201 "$(tail -1 <<<"$R")"
NOTE_ID=$(head -1 <<<"$R" | jqget "['id']")
R=$(curl -s -o /dev/null -w '%{http_code}' -X PUT $B/api/notes/$NOTE_ID -H "$A" -d '{"title":"Zakupy!","content":"mleko","pinned":false}')
check "notatka: update" 200 "$R"
R=$(curl -s -H "$A" $B/api/notes | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d), d[0]['title'])")
[ "$R" = "1 Zakupy!" ] && check "notatka: lista" ok ok || check "notatka: lista" "1 Zakupy!" "$R"

# --- przypomnienia ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/reminders -H "$A" -d '{"title":"Umówić przegląd auta","remindAt":"2030-07-30T09:00:00Z"}')
check "przypomnienie: create" 201 "$(tail -1 <<<"$R")"
REM_ID=$(head -1 <<<"$R" | jqget "['id']")
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/reminders/$REM_ID/toggle -H "$A")
check "przypomnienie: toggle" 200 "$R"
R=$(curl -s -H "$A" "$B/api/reminders" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$R" = "0" ] && check "przypomnienie: odhaczone znika" ok ok || check "przypomnienie: odhaczone znika" 0 "$R"

# --- wydarzenia ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/events -H "$A" -d '{"title":"Fryzjer","startsAt":"2030-07-25T10:00:00Z","description":"u Magdy"}')
check "wydarzenie: create" 201 "$(tail -1 <<<"$R")"
R=$(curl -s -H "$A" "$B/api/events?from=2030-07-25T00:00:00Z&to=2030-07-26T00:00:00Z" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$R" = "1" ] && check "wydarzenie: filtr zakresu" ok ok || check "wydarzenie: filtr zakresu" 1 "$R"

# --- obowiązki (z powtarzaniem) ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/tasks -H "$A" -d '{"title":"Podlać kwiaty","dueDate":"2030-07-24","repeat":"weekly"}')
check "obowiązek: create" 201 "$(tail -1 <<<"$R")"
TASK_ID=$(head -1 <<<"$R" | jqget "['id']")
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/tasks/$TASK_ID/toggle -H "$A")
check "obowiązek: toggle" 200 "$R"
R=$(curl -s -H "$A" "$B/api/tasks?includeDone=true" | python3 -c "
import sys,json; d=json.load(sys.stdin)
done=[t for t in d if t['done']]; todo=[t for t in d if not t['done']]
print(len(done), len(todo), todo[0]['dueDate'] if todo else '-')")
[ "$R" = "1 1 2030-07-31" ] && check "obowiązek: powtarzalny tworzy następny (+7 dni)" ok ok || check "obowiązek: powtarzalny tworzy następny" "1 1 2030-07-31" "$R"

# --- przepisy + jadłospis ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/recipes -H "$A" -d '{"title":"Spaghetti bolognese","ingredients":"makaron\nmięso mielone\npomidory","steps":"1. Ugotuj makaron\n2. Zrób sos","tags":["obiad","makaron"],"timeMinutes":40,"servings":4}')
check "przepis: create" 201 "$(tail -1 <<<"$R")"
RECIPE_ID=$(head -1 <<<"$R" | jqget "['id']")
R=$(curl -s -H "$A" "$B/api/recipes/random?tag=obiad" | jqget "['title']")
[ "$R" = "Spaghetti bolognese" ] && check "przepis: losowanie po tagu" ok ok || check "przepis: losowanie po tagu" "Spaghetti" "$R"
R=$(curl -s -w '\n%{http_code}' -X PUT $B/api/mealplan -H "$A" -d "{\"date\":\"2030-07-25\",\"mealType\":\"obiad\",\"recipeId\":\"$RECIPE_ID\"}")
check "jadłospis: upsert z przepisem" 200 "$(tail -1 <<<"$R")"
R=$(curl -s -H "$A" "$B/api/mealplan?from=2030-07-25&to=2030-07-25" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d[0]['recipeTitle'])")
[ "$R" = "Spaghetti bolognese" ] && check "jadłospis: join z tytułem przepisu" ok ok || check "jadłospis: join" "Spaghetti" "$R"

# --- dzienniczek ---
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/diary -H "$A" -d '{"date":"2030-07-24","mealType":"sniadanie","description":"owsianka z malinami","calories":350}')
check "dzienniczek: create" 201 "$(tail -1 <<<"$R")"
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/diary -H "$A" -d '{"date":"2030-07-24","mealType":"złytyp","description":"x"}')
check "dzienniczek: walidacja typu posiłku" 400 "$R"

# --- budżet: limit, transakcje, podsumowanie ---
R=$(curl -s -o /dev/null -w '%{http_code}' -X PUT $B/api/budget/limits -H "$A" -d '{"month":"2030-07","category":"jedzenie","limitGrosze":150000}')
check "budżet: limit" 200 "$R"
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/transactions -H "$A" -d '{"occurredOn":"2030-07-24","kind":"expense","amountGrosze":15799,"category":"jedzenie","description":"Biedronka"}')
check "transakcja: wydatek" 201 "$R"
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/transactions -H "$A" -d '{"occurredOn":"2030-07-01","kind":"income","amountGrosze":520000,"description":"wypłata"}')
check "transakcja: przychód" 201 "$R"
R=$(curl -s -H "$A" "$B/api/budget/summary?month=2030-07" | python3 -c "
import sys,json; d=json.load(sys.stdin)
c=[x for x in d['categories'] if x['category']=='jedzenie'][0]
print(d['incomeGrosze'], d['expenseGrosze'], c['spentGrosze'], c['limitGrosze'])")
[ "$R" = "520000 15799 15799 150000" ] && check "budżet: podsumowanie" ok ok || check "budżet: podsumowanie" "520000 15799 15799 150000" "$R"

# --- pliki (paragon do MinIO) ---
printf '\x89PNG\r\n\x1a\n' > /tmp/paragon-test.png; head -c 512 /dev/urandom >> /tmp/paragon-test.png
R=$(curl -s -w '\n%{http_code}' -X POST $B/api/files -H "$A" -F "file=@/tmp/paragon-test.png;type=image/png")
check "plik: upload do MinIO" 201 "$(tail -1 <<<"$R")"
FILE_ID=$(head -1 <<<"$R" | jqget "['id']")
R=$(curl -s -o /tmp/paragon-back.png -w '%{http_code}' -H "$A" $B/api/files/$FILE_ID)
check "plik: pobranie" 200 "$R"
cmp -s /tmp/paragon-test.png /tmp/paragon-back.png && check "plik: zawartość identyczna" ok ok || check "plik: zawartość" same diff
R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/transactions -H "$A" -d "{\"occurredOn\":\"2030-07-24\",\"kind\":\"expense\",\"amountGrosze\":4999,\"category\":\"dom\",\"receiptFileId\":\"$FILE_ID\"}")
check "transakcja z paragonem" 201 "$R"

# --- izolacja użytkowników ---
R2=$(curl -s -X POST $B/api/auth/register -d '{"email":"ania+'$SUFFIX'@test.pl","password":"sekret123","displayName":"Ania"}' | jqget "['token']")
R=$(curl -s -H "Authorization: Bearer $R2" $B/api/notes | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$R" = "0" ] && check "izolacja: Ania nie widzi notatek Kasi" ok ok || check "izolacja" 0 "$R"
R=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $R2" $B/api/files/$FILE_ID)
check "izolacja: cudzy plik -> 404" 404 "$R"

# --- powiadomienia push (tylko gdy ntfy działa) ---
if curl -s --max-time 3 "$N/v1/health" 2>/dev/null | grep -q '"healthy":true'; then
  echo "--- ntfy wykryte pod $N - testuję push (czekanie na dyspozytora: ${WAIT}s) ---"

  SETTINGS=$(curl -s -H "$A" $B/api/push/settings)
  TOPIC=$(echo "$SETTINGS" | jqget "['topic']")
  R=$(echo "$SETTINGS" | jqget "['enabled']")
  check "push: enabled=true" "True" "$R"
  check "push: sekretny temat (og-...)" "og-" "${TOPIC:0:3}"

  R=$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/push/test -H "$A")
  check "push: test -> 200" 200 "$R"
  sleep 1
  curl -s "$N/$TOPIC/json?poll=1" | grep -q "Powiadomienia push działają" \
    && check "push: wiadomość testowa dotarła do ntfy" ok ok \
    || check "push: wiadomość testowa dotarła do ntfy" ok brak

  PAST=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(minutes=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
  curl -s -o /dev/null -X POST $B/api/reminders -H "$A" -d "{\"title\":\"Wyjąć pranie z pralki\",\"remindAt\":\"$PAST\"}"
  sleep "$WAIT"
  CNT=$(curl -s "$N/$TOPIC/json?poll=1" | grep -c "Wyjąć pranie z pralki" || true)
  check "push: dyspozytor wysłał przypomnienie dokładnie raz" 1 "$CNT"

  TODAY=$(date +%F)
  curl -s -o /dev/null -X POST $B/api/tasks -H "$A" -d "{\"title\":\"Odkurzyć salon\",\"dueDate\":\"$TODAY\"}"
  R=$(curl -s -X PUT $B/api/push/settings -H "$A" -d '{"digestHour":0}' | jqget "['digestHour']")
  check "push: zmiana godziny podsumowania" 0 "$R"
  sleep "$WAIT"
  curl -s "$N/$TOPIC/json?poll=1" | grep -q "obowiąz" \
    && check "push: poranne podsumowanie obowiązków" ok ok \
    || check "push: poranne podsumowanie obowiązków" ok brak

  R=$(curl -s -o /dev/null -w '%{http_code}' -X PUT $B/api/push/settings -H "$A" -d '{"digestHour":25}')
  check "push: walidacja godziny (25 -> 400)" 400 "$R"
  NEWTOPIC=$(curl -s -X POST $B/api/push/regenerate -H "$A" | jqget "['topic']")
  [ "$NEWTOPIC" != "$TOPIC" ] && check "push: regeneracja tematu" ok ok || check "push: regeneracja tematu" nowy "$NEWTOPIC"
else
  echo "--- ntfy niedostępne pod $N - pomijam testy push ---"
fi

echo; echo "WYNIK: $PASS OK, $FAIL FAIL"
[ $FAIL = 0 ]
