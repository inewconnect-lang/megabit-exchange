# Megabit Exchange: instalacja (PL)

Platforma do handlu megabitami transferu internetowego między użytkownikami.

- **Konto:** otwarcie kosztuje **9,99 USD**, płatne przez **Revolut**. W zamian użytkownik dostaje **10 000 wirtualnych USD** do handlu.
- **Handel:** konta handlują ze sobą w arkuszu zleceń.
- **Platforma:** sprzedaje nowe megabity po cenie indeksu GWT i odkupuje je 2% poniżej niej.
- **Minimalne zlecenie:** 100 Mb.
- **Języki interfejsu:** angielski (domyślny), polski, niemiecki i hiszpański.

Pełna dokumentacja techniczna po angielsku jest w `README.md`.

## 1. Uruchomienie na komputerze

Wymagany Node.js 20.12+ (zalecany 22 LTS).

```bash
npm ci
npm start      # http://localhost:3000, bez płatności (PAYMENT_PROVIDER=none)
npm test       # testy, w tym symulowana płatność Revolut
```

## 2. Serwer z Dockerem i HTTPS

Potrzebujesz VPS-a z Linuksem (2 vCPU, 2–4 GB RAM, np. Hetzner CX23) i domeny.

1. Ustaw w DNS rekord **A** domeny na adres IP serwera.
2. Zainstaluj Dockera: `curl -fsSL https://get.docker.com | sh`.
3. Wgraj projekt na serwer i uruchom:
   ```bash
   cp .env.example .env
   nano .env      # DOMAIN, PUBLIC_URL i ustawienia płatności (punkt 3)
   docker compose up -d --build
   ```
4. Caddy sam pobierze certyfikat HTTPS.

## 3. Płatności Revolut

### Wariant A: Revolut Merchant API (automatyczny, zalecany)

Wymaga konta **Revolut Business** z włączonymi płatnościami online (Merchant).

1. W Revolut Business wejdź w **Merchant → APIs** i skopiuj **Secret API key**. Najpierw testuj kluczem z trybu sandbox.
2. W `.env` ustaw:
   ```
   PAYMENT_PROVIDER=revolut
   REVOLUT_ENV=sandbox            # po testach: production
   REVOLUT_SECRET_KEY=sk_...
   PUBLIC_URL=https://twoja.domena
   ```
3. Zarejestruj webhook:
   ```bash
   docker compose exec app node scripts/revolut-webhook.js
   ```
4. Wpisz wypisany sekret do `REVOLUT_WEBHOOK_SECRET=wsk_...` i uruchom ponownie: `docker compose up -d`.

Jak przebiega płatność:

1. Klient klika „Zapłać 9,99 USD przez Revolut” i trafia na bezpieczną stronę płatności Revolut. Platforma nie widzi danych karty.
2. Po zapłacie Revolut wysyła podpisany webhook.
3. Serwer sprawdza stan zamówienia bezpośrednio w API Revolut i dopiero wtedy aktywuje konto, dodając 10 000 USD.
4. Gdyby webhook nie dotarł, serwer co minutę sam sprawdza oczekujące płatności.

### Wariant B: link Revolut.me (ręczny, bez konta firmowego)

W `.env` ustaw:

```
PAYMENT_PROVIDER=manual
MANUAL_PAYMENT_URL=https://revolut.me/twojanazwa
MANUAL_PAYMENT_RECIPIENT=@twojanazwa
```

Klient widzi kwotę, Twój link i unikalny numer referencyjny, np. `MBX-7F3K2QZP`. Gdy wpłata dotrze, potwierdzasz ją jednym poleceniem:

```bash
docker compose exec app node scripts/admin.js pending                # lista oczekujących wpłat
docker compose exec app node scripts/admin.js confirm MBX-7F3K2QZP   # aktywuje konto
docker compose exec app node scripts/admin.js grant email@domena.pl  # darmowy pakiet
docker compose exec app node scripts/admin.js stats                  # liczba kont, przychód, transakcje
```

## 4. Zasady rynku (do zmiany w `.env`)

- `ACCOUNT_FEE=9.99`, `PACKAGE_USD=10000`: cena konta i wirtualna kwota w pakiecie.
- `TOPUP_ENABLED=true`: użytkownik może dokupić kolejne pakiety.
- `MIN_ORDER_MB=100`: minimalne zlecenie.
- `FEE_RATE=0.002`: prowizja od transakcji (0,20%).
- `ISSUE_PREMIUM=0`: platforma sprzedaje nowe megabity po cenie indeksu.
- `REDEEM_DISCOUNT=0.02`: platforma odkupuje megabity 2% poniżej ceny indeksu.
  - Ustaw `REDEEM_ENABLED=false`, jeśli sprzedaż ma być możliwa tylko innym użytkownikom.

## 5. Kopie zapasowe

Cały stan platformy to plik `data/megabit.db`. Codziennie rób kopię i trzymaj ją poza serwerem.

## 6. Prawo i podatki: przed startem

To nie jest porada prawna. Te punkty skonsultuj z prawnikiem i księgowym.

- **Brak wypłat:** wirtualne dolary i megabity nie mogą dać się wypłacić, wymienić na pieniądze ani przenieść poza platformę. Nie może być też nagród.
  - Jeśli to się zmieni, platforma prawdopodobnie stanie się usługą finansową (MiFID II, MiCA) albo grą hazardową.
- **Regulamin i polityka prywatności:** podlinkuj je w `TERMS_URL` i `PRIVACY_URL` (RODO).
  - W formularzu płatności klient akceptuje warunki i prosi o natychmiastowy dostęp.
  - Tym samym traci 14-dniowe prawo odstąpienia, zgodnie z prawem konsumenckim UE.
- **VAT:** sprzedaż usługi cyfrowej konsumentom z UE to zwykle VAT według stawki kraju klienta (procedura OSS) oraz faktury.
- **Revolut:** potwierdź z Revolut, że taki model działalności jest zgodny z ich warunkami dla sprzedawców.
