# Flipping the repo to public / Repoyu public'e çevirme

Decision (2026-09-19): **MIT license** + **public**. The MacBook could not clone a private repo without
extra credentials, so the flip happened first and the Mac test follows it.
Karar (19 Eyl 2026): **MIT lisans** + **public**. MacBook, ek kimlik bilgisi olmadan private repoyu
klonlayamıyordu; bu yüzden önce public yapıldı, Mac testi sonrasında.

Preparation is already done: `LICENSE` (MIT), English-first README, `Info.plist` copyright string,
bilingual source comments. Nothing in the code blocks the flip.
Hazırlık tamam: `LICENSE` (MIT), İngilizce öncelikli README, `Info.plist` telif metni, iki dilli kod
yorumları. Kodda flip'i engelleyen hiçbir şey yok.

## Status: flipped to public on 2026-09-19 / Durum: 19 Eyl 2026'da public yapıldı

Verified anonymously (no token): `git ls-remote https://github.com/tarcanm/alttab-personal.git` returned
the branch list, and the web page answered `200`.
Anonim olarak doğrulandı (token yok): `git ls-remote` dal listesini döndürdü ve web sayfası `200` yanıtı verdi.

## Flip (2 API calls) / Flip (2 API çağrısı)

```bash
TOKEN=$GITHUB_TOKEN

# 1) Turn issues/wiki/discussions off so there is no support load.
#    Destek yükü olmasın diye Issues/wiki/discussions kapalı.
curl -s -X PATCH -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  -d '{"has_issues":false,"has_wiki":false,"has_discussions":false,"description":"Windows-style option+Tab window switcher for macOS. Written from scratch in Swift/AppKit. MIT."}' \
  https://api.github.com/repos/tarcanm/alttab-personal

# 2) Make it public / Public yap
curl -s -X PATCH -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  -d '{"private":false}' \
  https://api.github.com/repos/tarcanm/alttab-personal
```

Verify / Doğrula:

```bash
curl -s -H "Authorization: token $TOKEN" https://api.github.com/repos/tarcanm/alttab-personal \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['full_name'], 'private:', d['private'], 'issues:', d['has_issues'])"
```

## Pre-flip checklist / Flip öncesi kontrol listesi

- [x] No secrets in the repo, including the whole git history (scanned 2026-09-19: clean, and personal
      host/user names were generalised out of the tests and the setup script)
      / Repo'da secret yok, git geçmişi dahil (19 Eyl taraması: temiz; kişisel makine/kullanıcı adları
      testlerden ve kurulum betiğinden çıkarıldı)
- [x] Linux side verified on a real desktop: Alt+Tab switches windows, autostart and the modifier
      repair survive a login / Linux tarafı gerçek masaüstünde doğrulandı
- [ ] `make app` builds cleanly on the MacBook / MacBook'ta `make app` hatasız derlendi
- [ ] `⌘ + Tab` works, raises the selected window and suppresses the system switcher
      / `⌘ + Tab` çalışıyor, doğru pencereyi öne getiriyor ve sistem değiştiricisini bastırıyor
- [ ] The README steps work end to end (clone, build, permission, test)
      / README'deki adımlar uçtan uca çalışıyor (klon, derleme, izin, test)

## After the flip (optional) / Flip sonrası (opsiyonel)

- Add a short repo description and a screenshot or GIF (`![demo](docs/demo.gif)` in the README)
  / Kısa açıklama + ekran görüntüsü veya GIF ekle
- GitHub Release `v0.1.0`: source only, we do not ship unsigned `.app` bundles
  / Sadece kaynak kod; imzasız `.app` dağıtmıyoruz
- README section on signing with your own developer certificate (keeps the TCC permission stable)
  / Kendi geliştirici sertifikanla imzalama bölümü (TCC izni kalıcı olsun diye)
