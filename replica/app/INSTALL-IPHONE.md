# Handspan na tvom iPhoneu (bez Xcodea, s xtoolom)

Ovo su upute za Intel Mac koji ne može pokrenuti Xcode 26 i za besplatni Apple ID (bez plaćenog Apple Developer računa).

## Kako to radi

1. **GitHub gradi aplikaciju.** Na GitHubovom Macu (`macos-26`, Xcode 26) posao *App build (iPhone, unsigned)* napravi nepotpisani `Handspan.app` za pravi iPhone i spremi ga kao preuzimanje `Handspan-iphone`.
2. **xtool je potpisuje i instalira.** Na tvom Macu [xtool](https://github.com/xtool-org/xtool) potpiše aplikaciju tvojim Apple ID-jem i preko USB kabela je stavi na iPhone. Za to xtool **ne treba Xcode**.

Zašto ne gradimo sa samim xtoolom? xtool na macOS-u za gradnju traži instaliran Xcode (zbog iOS SDK-a), a na Linuxu traži `Xcode.xip` i Linux računalo s USB pristupom iPhoneu. Uz to bi cijeli projekt trebalo prebaciti u SwiftPM oblik. Gradnja na GitHubu + `xtool install` izbjegava sve to i ništa u aplikaciji ne mijenja.

## Što ti treba

- **Mac s macOS 14 (Sonoma) ili novijim.** xtool radi i na Intelu i na Apple Siliconu. Provjeri:  → O ovom Macu.
- **iPhone s iOS-om 26 ili novijim.** Aplikacija je napravljena za iOS 26. Provjeri: Postavke → Općenito → Informacije → Verzija iOS-a.
- **USB kabel** za iPhone.
- **Apple ID** (besplatni je dovoljan) s uključenom dvofaktorskom provjerom.
- **Homebrew** (nije obavezno, ali je lakše). Ako ga nemaš: <https://brew.sh>.

## Korak 1: instaliraj xtool (jednom)

U Terminalu:

```bash
brew install xtool-org/tap/xtool
xtool --help
```

Bez Homebrewa: s <https://github.com/xtool-org/xtool/releases/latest> preuzmi `xtool.app.zip`, raspakiraj, premjesti `xtool.app` u `Aplikacije`, otvori ga jednom i pokreni skriptu koju ponudi (doda naredbu `xtool` u Terminal).

## Korak 2: prijavi se Apple ID-jem (jednom)

```bash
xtool setup
```

Kad pita način prijave, odaberi **1: Password** (radi s besplatnim Apple ID-jem). Upiši e-mail Apple ID-ja, lozinku i šesteroznamenkasti kod koji stigne na tvoje Appleove uređaje. Podaci idu samo Appleu.

Ako te pita za iOS SDK ili `Xcode.xip`, to preskoči: za instalaciju gotove aplikacije nije potreban.

## Korak 3: pripremi iPhone (jednom)

1. Spoji iPhone kabelom na Mac, otključaj ga i dodirni **Vjeruj ovom računalu**.
2. Provjeri da ga xtool vidi:
   ```bash
   xtool devices
   ```
3. Uključi **Način za razvojne programere** (Developer Mode): Postavke → Privatnost i sigurnost → Način za razvojne programere → uključi, iPhone se ponovno pokrene, potvrdi s **Uključi**.
   Ako tu opciju ne vidiš, pojavit će se nakon prve instalacije u koraku 5.

## Korak 4: preuzmi aplikaciju s GitHuba

1. Otvori <https://github.com/shxmi03/echo-earning-agent/actions/workflows/ios.yml>.
2. Klikni najnovije zeleno pokretanje (na grani `main`).
   Nema ga ili je starije od 14 dana? Klikni **Run workflow** → **Run workflow** i pričekaj desetak minuta.
3. Na dnu, pod **Artifacts**, preuzmi **Handspan-iphone**.
4. U Terminalu raspakiraj. GitHub zip zapakira još jednom, pa se raspakira dvaput:
   ```bash
   cd ~/Downloads
   unzip -o Handspan-iphone.zip -d handspan-github
   unzip -o handspan-github/Handspan-iphone.zip -d handspan
   ls handspan          # treba pisati Handspan.app
   ```
   Ako je Safari već sam raspakirao preuzimanje (vidiš mapu `Handspan-iphone` s `.zip` unutra), pokreni samo drugi `unzip` s tom putanjom: `unzip -o Handspan-iphone/Handspan-iphone.zip -d handspan`.

## Korak 5: instaliraj

S iPhoneom spojenim i otključanim:

```bash
xtool install ~/Downloads/handspan/Handspan.app
```

Na kraju piše `Successfully installed!`.

Prvi put iPhone neće htjeti otvoriti aplikaciju dok joj ne vjeruješ: Postavke → Općenito → **Upravljanje VPN-om i uređajima** → pod "Aplikacija razvojnog programera" odaberi svoj Apple ID → **Vjeruj**.

## Svakih 7 dana

S besplatnim Apple ID-jem potpis vrijedi **7 dana**. Nakon toga se aplikacija više ne otvara (podaci ostaju). Ponovi korak 5 (i korak 4 ako želiš najnoviju verziju). Ograničenja besplatnog računa: najviše 3 takve aplikacije na uređaju i 10 novih App ID-jeva tjedno.

## Što radi, a što ne

| | S besplatnim Apple ID-jem |
|---|---|
| Lekcije, mikrofon, prepoznavanje tonova | radi |
| MIDI klavijatura (USB ili Bluetooth) | radi |
| Prijava kodom na e-mail (Supabase) | radi |
| Podsjetnik za vježbanje (lokalne obavijesti) | radi |
| **Kupnja pretplate (paywall)** | **ne radi**: cijene se prikazuju, ali kupnja javi grešku jer pretplate još ne postoje u App Store Connectu. Treba plaćeni Apple Developer račun. |

## Kad nešto zapne

- **`xtool devices` ne vidi iPhone:** drugi kabel ili USB priključak, otključaj iPhone, ponovno potvrdi "Vjeruj ovom računalu".
- **Greška o bundle ID-ju (`app.handspan.ios` je zauzet):** javi, promijenit ćemo ID za tvoju probnu verziju.
- **Greška 503 ili neuspjela prijava:** `brew upgrade xtool` pa `xtool auth logout` i ponovno `xtool setup`.
- **"Untrusted Developer" / aplikacija se ne otvara:** korak "Vjeruj" iz koraka 5.
- **Aplikacija se odmah zatvori nakon tjedan dana:** istekao je potpis, ponovi korak 5.
