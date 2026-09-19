# Flipping the repo to public / Repoyu public'e çevirme

Decision (2026-09-19): **MIT license** + **public after the Mac test passes**.
Karar (19 Eyl 2026): **MIT lisans** + **Mac testi geçtikten sonra public**.

Preparation is already done: `LICENSE` (MIT), English-first README, `Info.plist` copyright string,
bilingual source comments. Nothing in the code blocks the flip.
Hazırlık tamam: `LICENSE` (MIT), İngilizce öncelikli README, `Info.plist` telif metni, iki dilli kod
yorumları. Kodda flip'i engelleyen hiçbir şey yok.

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

- [ ] `make app` builds cleanly on the MacBook / MacBook'ta `make app` hatasız derlendi
- [ ] `⌥ + Tab` works and raises the selected window / `⌥ + Tab` çalışıyor, doğru pencereyi öne getiriyor
- [ ] The README steps work end to end (clone, build, permission, test)
      / README'deki adımlar uçtan uca çalışıyor (klon, derleme, izin, test)
- [ ] No secrets in the repo (scan on 2026-09-19: clean) / Repo'da secret yok (19 Eyl taraması: temiz)

## After the flip (optional) / Flip sonrası (opsiyonel)

- Add a short repo description and a screenshot or GIF (`![demo](docs/demo.gif)` in the README)
  / Kısa açıklama + ekran görüntüsü veya GIF ekle
- GitHub Release `v0.1.0`: source only, we do not ship unsigned `.app` bundles
  / Sadece kaynak kod; imzasız `.app` dağıtmıyoruz
- README section on signing with your own developer certificate (keeps the TCC permission stable)
  / Kendi geliştirici sertifikanla imzalama bölümü (TCC izni kalıcı olsun diye)
