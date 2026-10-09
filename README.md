# Megabit Exchange

A peer-to-peer trading platform for three fictional instruments: **megabits of internet transfer**.

- **Paid accounts:** opening an account costs **9.99 USD**, paid through **Revolut**. The fee credits **10,000 virtual USD** for trading. More packages can be bought later.
- **Users trade with each other** in a real order book with price-time priority.
- **The platform takes part on fixed terms tied to the Global Transfer Index (GTI):** it **sells new megabits at the index price** and **buys them back 2% below it**. That keeps every instrument's value anchored to the index, while users trade inside that band.
- **Instruments:** MBF (fiber, β 1.0), MBM (mobile, β 1.6) and MBS (satellite, β 0.6), at about $0.10–0.18 per Mb. Index price = `base × (GTI / 1,184)^β`. The GTI is simulated or follows real Cloudflare Radar traffic.
- **Orders:** minimum order 100 Mb (about $10). "Buy megabits" packages, market and limit orders. The order book shows user orders together with the platform's terms. The tape shows only real trades.
- **Network news:** RSS aggregator in 4 languages, sourced "Internet in numbers" facts, and a log of simulated index events.
- **Interface:** English by default, plus Polish, German and Spanish. Light and dark themes, works on phones.

> Virtual dollars and megabits have **no monetary value** and **cannot be withdrawn**. See [Legal notes](#legal-notes) before you launch.

---

## Quick start (local)

Requirements: **Node.js 20.12+** (22 LTS recommended).

```bash
npm ci
npm start             # http://localhost:3000, payments off (PAYMENT_PROVIDER=none)
npm test              # API + unit tests, including a mocked Revolut flow
npm run build:demo    # single-file preview (market, book and payments simulated in the browser)
```

## Production with Docker and automatic HTTPS

This needs a Linux VPS with 2 vCPU and 2–4 GB RAM, Docker and a domain.

```bash
cp .env.example .env
nano .env    # DOMAIN, PUBLIC_URL, payment settings (see below)
docker compose up -d --build
```

Caddy gets the Let's Encrypt certificate automatically. Useful commands:

- `docker compose logs -f app`
- `docker compose exec app node scripts/admin.js stats`

Without Docker, use the nginx and systemd files in `deploy/`; the steps are in INSTALACJA.md.

---

## Payments with Revolut

Every new account starts as **pending**. A paid package activates it and credits `PACKAGE_USD` (default 10,000) virtual dollars. Crediting is idempotent: one payment is credited once, whichever path confirms it.

### Option A: Revolut Merchant API (automatic, recommended)

This needs a **Revolut Business** account with online payments (Merchant) enabled.

1. In Revolut Business, go to **Merchant → APIs** and copy the **Secret API key**. Test first with the sandbox key.
2. In `.env`, set:
   - `PAYMENT_PROVIDER=revolut`
   - `REVOLUT_ENV=sandbox` (later `production`)
   - `REVOLUT_SECRET_KEY=sk_...`
   - `PUBLIC_URL=https://your.domain`
3. Register the webhook and copy the signing secret it prints into `REVOLUT_WEBHOOK_SECRET`, then restart:
   ```bash
   npm run revolut:webhook          # Docker: docker compose exec app node scripts/revolut-webhook.js
   ```

The payment flow:

1. "Pay 9.99 USD with Revolut" calls `POST /api/orders` on Revolut with amount 999 and USD.
2. The customer goes to Revolut's **hosted checkout page** (`checkout_url`). The platform never sees card details.
3. Revolut sends a signed webhook (`Revolut-Signature`, HMAC-SHA256, 5-minute replay window).
4. The server **re-reads the order** with `GET /api/orders/{id}`. It credits the package only when the state is `completed` or `authorised`; the webhook body itself is never trusted.
5. After paying, the customer returns to `/?payment=<id>#account`, and the page polls until the account is active.
6. A background job also polls pending orders every minute, so payments still confirm if a webhook is lost.

### Option B: Revolut.me link (manual, no Business account)

Set `PAYMENT_PROVIDER=manual`, `MANUAL_PAYMENT_URL=https://revolut.me/yourname` and `MANUAL_PAYMENT_RECIPIENT=@yourname`.

- The customer sees the amount, your Revolut link and a unique reference, e.g. `MBX-7F3K2QZP`.
- When the money arrives, you confirm it:

```bash
npm run admin -- pending                 # list waiting payments
npm run admin -- confirm MBX-7F3K2QZP    # credit the package and activate the account
npm run admin -- grant user@example.com  # free package (tests, partners)
npm run admin -- users | stats
```

### Option C: no fee

`PAYMENT_PROVIDER=none` activates accounts immediately. Use it for development or a private demo.

---

## How the market works

| | |
|---|---|
| Order book | Price-time priority between accounts. An incoming order takes the best prices; at equal prices other users come before the platform. |
| Platform | Sells any amount of new megabits at the index price (`ISSUE_PREMIUM`), buys any amount back at index − 2 % (`REDEEM_DISCOUNT`). Resting user orders that the moving terms reach are filled automatically. |
| Orders | Market and limit (good until cancelled). Minimum 100 Mb, steps of 100 Mb, limits within ±10 % of the index price. Self-trades are blocked. |
| Fees | 0.20 % of value; the order that takes liquidity pays at least $0.05. |
| Data | Candles and the tape are built from real trades only. The chart always shows the index price line and the platform band. |

Everything runs in one Node.js process with SQLite and an in-memory book rebuilt from the database at start-up. One VPS handles thousands of users.

## Configuration

All settings are environment variables, set in `.env`. `.env.example` lists every option with a comment. The main groups are:

- **Address:** `PUBLIC_URL`, `DOMAIN`
- **Payments:** `PAYMENT_PROVIDER`, `ACCOUNT_FEE`, `PACKAGE_USD`, `TOPUP_ENABLED`, and the `REVOLUT_*` and `MANUAL_*` settings
- **Legal pages:** `TERMS_URL` and `PRIVACY_URL`, linked at checkout
- **Trading rules:** `MIN_ORDER_MB`, `FEE_RATE`, `FEE_MIN_USD`, `PRICE_BAND`, `ISSUE_PREMIUM`, `REDEEM_DISCOUNT`, `REDEEM_ENABLED`
- **Index source:** `GWT_SOURCE=simulated|cloudflare` with `CLOUDFLARE_API_TOKEN`. Radar data is CC BY-NC 4.0, so it is for non-commercial use only.
- **News:** `NEWS_FETCH`, `NEWS_REFRESH_MINUTES`. Feeds are listed in `content/feeds.json`.

## Architecture

```
server/    Express API, WebSocket hub, SQLite, auth, trading (order book persistence),
           payments + Revolut client, news aggregator, Cloudflare Radar client
shared/    engine.js (index + reference prices), exchange.js (order book, matching, settlement)
public/    browser app (index.html, css/, js/app.js, js/i18n.js EN/PL/DE/ES, js/api.js)
scripts/   admin.js, revolut-webhook.js, build-demo.js
deploy/    Caddyfile, nginx.conf, systemd unit
test/      node --test suites
```

API overview:

- **Public:** `GET /api/config`, `/api/market/snapshot`, `/api/market/candles?sym&tf&limit`, `/api/news`, `/api/facts`
- **Auth:** `POST /api/auth/register|login|logout`
- **Account:** `GET/PATCH/DELETE /api/me`, `GET /api/account`
- **Orders:** `POST /api/orders`, `DELETE /api/orders/:id`
- **Payments:** `POST /api/payments/checkout`, `POST /api/payments/:id/refresh`, `GET /api/payments`
- **Webhook:** `POST /api/payments/revolut/webhook`
- **Live data:** `WS /ws` with `tick`, `fill`, `account` and `activated` messages

## Security

- **Passwords:** scrypt hashing.
- **Sessions:** random session tokens stored as SHA-256 hashes, in HttpOnly SameSite=Lax cookies.
- **CSRF:** the server checks the request origin and requires the `X-MBX` header.
- **Content security:** a strict CSP with no inline scripts.
- **Rate limits:** on sign-in, payments and orders.
- **Payments:** Revolut webhooks are signature-checked, and each order is re-read from Revolut before any credit. The secret key never reaches the browser.

**Backups:** the whole state is `data/megabit.db`. Run `sqlite3 data/megabit.db ".backup 'backup.db'"` daily and keep copies off the server.

## Legal notes

This section is not legal advice. Check these points with a lawyer and an accountant before launch.

- **What the fee buys:** access to a simulation plus virtual funds. Keep it that way: **no cash-out**, no prizes, no transfer of balances or megabits outside the platform. If units bought with money could be turned back into money, the platform would likely become a regulated financial service (MiFID II/MiCA) or gambling.
- **Consumer law (EU):** at checkout the customer accepts the terms and explicitly asks for immediate access, acknowledging that the 14-day withdrawal right ends at activation. Publish full terms and a privacy policy (`TERMS_URL`, `PRIVACY_URL`).
- **Tax:** a 9.99 USD digital service sold to EU consumers usually means VAT at the customer's country rate (the OSS scheme) and invoices.
- **Revolut:** confirm with Revolut that this business model is acceptable under their merchant terms before going live.
